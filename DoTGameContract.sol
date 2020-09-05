pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/Ownable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/IDotTokenContract.sol";
import "github.com/smartcontractkit/chainlink/evm-contracts/src/v0.6/ChainlinkClient.sol";

/**
 * @title DeFi Of Thrones Game Contract
 * @author DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract DoTGameContract is ChainlinkClient, Ownable {
    //Debug purpose must be false if deployed over local VM - Must be deleted for production
    bool isOnChain = false;
    uint256 constant public MAX_INT_NUMBER = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 constant public SECONDS_IN_DAYS = 86400;

    //War struct, for each war a War variable will be created 
    struct War {
        uint256 startTime;
        uint256 duration;
        uint256 ticketPrice;
        uint256 purchasePeriodInDays;//TODO Change for seconds
        bytes32 winningHouse;
        uint256 ticketsBought;
        uint256 warFees;
        uint256 warFeesPercent;
        int256 multiplicator;
        mapping(address => User) users;
        mapping(bytes32 => House)  houses;
    }
    //House struct, each war contains an map of 2 houses (could be more ine the future)
    struct House {
        bytes32 houseTicker;
        uint256 openPrice;
        uint256 closePrice;
        uint256 ticketsBought;
    }
    //User struct, each war contains a map of users
    //Each user can pledge allegiance for a house, buy tickets and switch house by paying fees
    struct User {
        bytes32 houseTicker;
        uint256 ticketsBought;
        uint256 fees;
    }
    
    //DOTX Contract Address
    IDotTokenContract private dotxToken;
    
    //Array of Wars 
    mapping(uint256 => War) public wars;
    //Index of the current war
    uint256 public currentWarIndex = 0;
    //First house for the current war
    bytes32 currentFirstHouseTicker;
    //Second house for the current war
    bytes32 currentSecondHouseTicker;
    
    //CHAINLINK VARS
    // The address of an oracle - you can find node addresses on https://market.link/search/nodes
    //address ORACLE_ADDRESS = 0xB36d3709e22F7c708348E225b20b13eA546E6D9c; ROPSTEN
    address public ORACLE_ADDRESS = 0x56dd6586DB0D08c6Ce7B2f2805af28616E082455;
    // The address of the http get > uint256 job
    string public JOBID = "b6602d14e4734c49a5e1ce19d45a4632";
    //LINK amount / transaction (oracle payment)
    uint256 public ORACLE_PAYMENT = 100000000000000000;
    
    //GENERAL VARS
    //Total fees paid by users
    uint256 public totalFees;
    //Precision for the select winner calculation
    uint256 public selecteWinnerPrecision = 10000;
    
    //EVENTS
    event WarStarted();
    event TicketBought();
    event openPriceFetched();
    event closePriceFetched();
    
    //MODIFIERS
    modifier onlyIfCurrentWarFinished() {
        require(wars[currentWarIndex].startTime.add(wars[currentWarIndex].duration) <= now || currentWarIndex == 0, "Current war not finished");
        _;
    }
    
    modifier onlyIfCurrentWarNotFinished() {
        require(wars[currentWarIndex].startTime.add(wars[currentWarIndex].duration) > now, "Current war finished");
        _;
    }
    
    modifier onlyIfTicketsPurchasable() {
        require((now.sub(wars[currentWarIndex].startTime) / SECONDS_IN_DAYS) < wars[currentWarIndex].purchasePeriodInDays,
        "Purchase tickets period ended");
        _;
    }
    
    modifier onlyIfPricesFetched(){
        require(getFirstHouse().openPrice != 0 && getSecondHouse().openPrice != 0, "Open prices not fetched");
        require(getFirstHouse().closePrice != 0 && getSecondHouse().closePrice != 0, "Close prices not fetched");
        _;
    }
    
    /**
     * Mock testing data 
     * Create a war for testing purpose
     * Must be deleted for production
     **/
    function mockData() private{
        currentWarIndex++;
        
        string memory firstHouseT = "ETH";
        string memory secondHouseT = "BTC";
        
        wars[currentWarIndex] = War(1599217802, 99999999999999999, 1000000000000000000, 1000, 0, 0, 0, 1, 10000);
        wars[currentWarIndex].houses[stringToBytes32(firstHouseT)] = House(stringToBytes32(firstHouseT), 0, 0, 0);
        wars[currentWarIndex].houses[stringToBytes32(secondHouseT)] = House(stringToBytes32(secondHouseT), 0, 0, 0);
        
        currentFirstHouseTicker = stringToBytes32(firstHouseT);
        currentSecondHouseTicker = stringToBytes32(secondHouseT);
        
        wars[currentWarIndex].winningHouse = stringToBytes32("ETH");//DELETE
    }
    
    /**
     * Game contract constructor
     * Just pass the DoTx contract address in parameter
     **/
    constructor(address dotxTokenAddress) public {
        if(isOnChain){
            //Setup Chainlink address for the network
            setPublicChainlinkToken();
        }
        
        //Implement DoTx contract interface by providing address
        dotxToken = IDotTokenContract(dotxTokenAddress);
        
        //Delete for production
        mockData();
    }
    
    /**************************
            WAR METHODS
    ***************************/
    
    /**
     * Start a war only if the previous is finished
     * Parameters :
     * _firstHouseTicker First house ticker 
     * _secondHouseTicker Second house ticker 
     * _duration Duration of the war in seconds 
     * _ticketPrice Ticket price : Number of DoTx needed to buy a ticket (in wei precision)
     * _purchasePeriodInDays Number of days where the users can buy tickets from the starting date
     * _warFeesPercent How many % fees it will cost to user to switch house 
     * _multiplicator Precision of the prices receive from WS
     **/
    function startWar(string memory _firstHouseTicker, string memory _secondHouseTicker, uint256 _duration, uint256 _ticketPrice, 
    uint256 _purchasePeriodInDays, uint256 _warFeesPercent, int256 _multiplicator) 
    public onlyOwner onlyIfCurrentWarFinished returns(bool) {
        currentWarIndex++;
        //Create war        
        wars[currentWarIndex] = War(now, _duration, _ticketPrice, _purchasePeriodInDays, 0, 0, 0, _warFeesPercent, _multiplicator);
        
        //Create first house
        currentFirstHouseTicker = stringToBytes32(_firstHouseTicker);
        wars[currentWarIndex].houses[currentFirstHouseTicker] = House(currentFirstHouseTicker, 0, 0, 0);
        //Create second house
        currentSecondHouseTicker = stringToBytes32(_secondHouseTicker);
        wars[currentWarIndex].houses[currentSecondHouseTicker] = House(currentSecondHouseTicker, 0, 0, 0);
        
        emit WarStarted();
        
        fetchFirstDayPrices();
        
        return true;
    }
    
     /**
     * Buy ticket(s) for the current war - only if tickets are purchasable -> purchasePeriodInDays
     * Parameters :
     * _houseTicker House ticker 
     * _numberOfTicket The number of tickets the user wants to buy
     **/
    function buyTickets(string memory _houseTicker, uint _numberOfTicket) public onlyIfTicketsPurchasable returns(bool) {
        War storage war = wars[currentWarIndex];
        if(isOnChain){
            //Check if user has approve DoTx contract with MAX_INT_NUMBER
            require(dotxToken.allowance(msg.sender, address(this)) == MAX_INT_NUMBER, "Please approve the max amount");
        }
        
        //Check if user has enough DoTx to spend
        uint256 userAmountSpend = getWarTicketPrice(currentWarIndex).mul(_numberOfTicket);
        if(isOnChain){
            require(dotxToken.balanceOf(msg.sender) >= userAmountSpend, "Not enough DoTx in balance to buy ticket(s)");
        }
        
        //Check if house is in competition
        bytes32 houseTicker = stringToBytes32(_houseTicker);
        require(checkIfHouseInCompetition(_houseTicker), "House not in competition");
        
        //Allow user to only buy tickets for one single House
        bytes32 userHouseTicker = getCurrentUser().houseTicker;
        require(userHouseTicker == houseTicker || userHouseTicker == 0, "You can't buy tickets for the other house - You can switch if you want");
        
        //Update user tickets
        wars[currentWarIndex].users[msg.sender].houseTicker = houseTicker;
        wars[currentWarIndex].users[msg.sender].ticketsBought = getCurrentUser().ticketsBought.add(_numberOfTicket);
        
        //Increase tickets bought for the house
        war.houses[houseTicker].ticketsBought = war.houses[houseTicker].ticketsBought.add(_numberOfTicket);
        
        //Increase total tickets bought
        war.ticketsBought = war.ticketsBought.add(_numberOfTicket);
        
        //Propagate TicketBought event
        emit TicketBought();
        
        //Transfer DoTx
        if(isOnChain){
            return dotxToken.transferFrom(msg.sender, address(this), userAmountSpend);
        }else{
            return true;
        }
    }
    
    /**
     * Switch house for the user - only if tickets are purchasable -> purchasePeriodInDays
     * Parameters :
     * _fromHouseTicker Current house user pledged allegiance 
     * _toHouseTicker the house user wants to join
     **/
    function switchHouse(string memory _fromHouseTicker, string memory _toHouseTicker) public onlyIfTicketsPurchasable returns(bool) {
        //Check if houses are in competition
        require(checkIfHouseInCompetition(_fromHouseTicker), "House not in competition");
        require(checkIfHouseInCompetition(_toHouseTicker), "House not in competition");
        
        //Check if user belongs to _fromHouse 
        require(getCurrentUser().houseTicker == stringToBytes32(_fromHouseTicker), "User doesn't belong to fromHouse");
        
        //Requires at least one ticket bought
        uint256 ticketsBoughtByUser = getCurrentUser().ticketsBought;
        require(ticketsBoughtByUser > 0, "User can't switch without tickets");
        
        //Switch house for user
        wars[currentWarIndex].users[msg.sender].houseTicker = stringToBytes32(_toHouseTicker);
        
        //Update fromHouse tickets
        uint256 fromHouseTickets = getTicketsBoughtForHouse(currentWarIndex, _fromHouseTicker);
        wars[currentWarIndex].houses[stringToBytes32(_fromHouseTicker)].ticketsBought = fromHouseTickets.sub(ticketsBoughtByUser);
        
        //Update toHouse tickets
        uint256 toHouseTickets = getTicketsBoughtForHouse(currentWarIndex, _toHouseTicker);
        wars[currentWarIndex].houses[stringToBytes32(_toHouseTicker)].ticketsBought = toHouseTickets.add(ticketsBoughtByUser);
        
        
        //Update user fees
        uint256 feesToBePaid = getFeesForSwitchHouse();
        //Update fees fot user
        wars[currentWarIndex].users[msg.sender].fees = getCurrentUser().fees.add(feesToBePaid);
        //Update war fees
        wars[currentWarIndex].warFees = wars[currentWarIndex].warFees.add(feesToBePaid);
        //Update total fees
        totalFees = totalFees.add(feesToBePaid);
        
        //Get fees from user wallet
        if(isOnChain){
            return dotxToken.transferFrom(msg.sender, address(this), feesToBePaid);
        }else{
            return true;
        }
    }
    
    /**
     * Allow users who pledged allegiance to the winning house to claimr bought tickets + reward
     * Parameters :
     **/
    function claimRewardAndTickets() public onlyIfCurrentWarFinished returns(bool) {
        //A winner house must be elected
        require(wars[currentWarIndex].winningHouse != 0, "Winner not elected");
        
        //Check if user has at least one ticketsBought 
        require(wars[currentWarIndex].users[msg.sender].ticketsBought > 0, "User doesn't have ticket");
        
        //Check if user belongs to winning house
        bytes32 winningHouse = wars[currentWarIndex].winningHouse;
        require(getCurrentUser().houseTicker == winningHouse, "User doesn't belong to winning house");
        
        
        //DoTx in user balance
        uint256 reward = getCurrentReward(bytes32ToString(winningHouse));
        
        //Set ticketsBought to 0
        wars[currentWarIndex].users[msg.sender].ticketsBought = 0;
        
        if(isOnChain){
            dotxToken.transfer(msg.sender, reward.add(getUserDoTxInBalance(currentWarIndex)));
        }
    }
    
    function testClaim() public {
        
    }
    
    /*****************************
            PRICES METHODS
    ******************************/
    
    /**
     * Fetch the prices for the 2 houses the first day for the current war
     **/
    function fetchFirstDayPrices() public onlyOwner {
        require(isFirstDayForCurrentWar(), "Impossible to get first day prices after the first day has passed");
        require(getFirstHouse().openPrice == 0 && getSecondHouse().openPrice == 0, "Open prices already fetched");
        
        queryChainLinkPrice(bytes32ToString(currentFirstHouseTicker), this.firstHouseOpen.selector);
        queryChainLinkPrice(bytes32ToString(currentSecondHouseTicker), this.secondHouseOpen.selector);
    }

    /**
     * Fetch the prices for the 2 houses the last day for the current war
     **/
    function fetchLastDayPrices() public onlyOwner onlyIfCurrentWarFinished {
        require(getFirstHouse().closePrice == 0 && getSecondHouse().closePrice == 0, "Close prices already fetched");
        
        queryChainLinkPrice(bytes32ToString(currentFirstHouseTicker), this.firstHouseClose.selector);
        queryChainLinkPrice(bytes32ToString(currentSecondHouseTicker), this.secondHouseClose.selector);
    }
    
    /**
     * Elect the winner base on open prices & close prices
     **/
    function selectWinner() public onlyOwner onlyIfCurrentWarFinished onlyIfPricesFetched {
        
        uint256 fstHOpen = getFirstHouse().openPrice;
        uint256 fstHClose = getFirstHouse().closePrice;
        uint256 sndHOpen = getSecondHouse().openPrice;
        uint256 sndHClose = getSecondHouse().closePrice;
        
        uint256 firstHousePerf = ((fstHClose.sub(fstHOpen)).mul(selecteWinnerPrecision)).div(fstHOpen);
        uint256 secondHousePerf = ((sndHClose.sub(sndHOpen)).mul(selecteWinnerPrecision)).div(sndHOpen);
        
        //Set winner house
        wars[currentWarIndex].winningHouse = firstHousePerf > secondHousePerf ? currentFirstHouseTicker : currentSecondHouseTicker;
    }
    
    /*******************************
            CHAINLINK METHODS
    ********************************/
    
    // 
    /**
     * Creates a Chainlink request with the uint256 multiplier job to retrieve a price for a coin
     * _fsym from symbol
     * _selector handler method called by Chainlink Oracle
     **/
    function queryChainLinkPrice(string memory _fsym, bytes4 _selector) public onlyOwner{
        // newRequest takes a JobID, a callback address, and callback function as input
        Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(JOBID), address(this), _selector);

        //Call Coingecko from DeFi Of Thrones API (code available in official git repo under WS folder)
        req.add("get", append("https://us-central1-defiofthrones.cloudfunctions.net/getCurrentPrice?fsym=", _fsym, "&tsym=usd", "", ""));
        // "path" to find the price in the json received
        req.add("path", "usd");
        // Multiply the price by multiplicator because Solidty can only manage Integer type
        req.addInt("times", wars[currentWarIndex].multiplicator);
        // Sends the request with the amount of payment specified to the oracle
        sendChainlinkRequestTo(ORACLE_ADDRESS, req, ORACLE_PAYMENT);
    }
    /**
     * Handler method called by Chainlink for the first house open price 
     **/
    function firstHouseOpen(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId){
        wars[currentWarIndex].houses[currentFirstHouseTicker].openPrice = _price;
        openPriceEvent();
    }
    /**
     * Handler method called by Chainlink for the second house open price 
     **/
    function secondHouseOpen(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId){
        wars[currentWarIndex].houses[currentSecondHouseTicker].openPrice = _price;
        openPriceEvent();
    }
    /**
     * Handler method called by Chainlink for the first house close price 
     **/
    function firstHouseClose(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId){
        wars[currentWarIndex].houses[currentFirstHouseTicker].closePrice = _price;
        closePriceEvent();
    }
    /**
     * Handler method called by Chainlink for the second house close price 
     **/
    function secondHouseClose(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId){
        wars[currentWarIndex].houses[currentSecondHouseTicker].closePrice = _price;
        closePriceEvent();
    }
    /**
     * Emit openPriceFetched event if needed
     **/
    function openPriceEvent() private {
        if(getFirstHouse().openPrice != 0 && getSecondHouse().openPrice != 0){
            emit openPriceFetched();
        }
    }
    /**
     * Emit closePriceFetched event if needed
     **/
    function closePriceEvent() private {
        if(getFirstHouse().closePrice != 0 && getSecondHouse().closePrice != 0){
            emit closePriceFetched();
        }
    }
    
    /*****************************
            GETTER METHODS
    ******************************/
    
    /**
     * Get the war duration for the war specified by _warIndex 
     **/
    function getWarDuration(uint256 _warIndex) view public returns(uint256) {
        return wars[_warIndex].duration;
    }
    
    /**
     * Get the war start time for the war specified by _warIndex 
     **/
    function getWarStartTime(uint256 _warIndex) view public returns(uint256) {
        return wars[_warIndex].startTime;
    }
    
    /**
     * Get the war ticket price for the war specified by _warIndex 
     **/
    function getWarTicketPrice(uint256 _warIndex) view public returns(uint256) {
        return wars[_warIndex].ticketPrice;
    }
    
     /**
     * Get the tickets bought for a house -> for the war specified by _warIndex 
     **/
    function getTicketsBoughtForHouse(uint256 _warIndex, string memory _houseTicker) public view returns(uint256){
        return wars[_warIndex].houses[stringToBytes32(_houseTicker)].ticketsBought;
    }
    
    /**
     * Get the total tickets bought for the war specified by _warIndex 
     **/
    function getTotalTicketsBought(uint256 _warIndex) public view returns(uint256){
        return wars[_warIndex].ticketsBought;
    }
    
    /**
     * Get the fees collected by the war specified by _warIndex 
     **/
    function getWarFees(uint256 _warIndex) public view returns(uint256){
        return wars[_warIndex].warFees;
    }
    
    /**
     * Get the first house ticker for the current war
     **/
    function getCurrentHouseTicker(bool _isFirst) public view returns(string memory){
        return bytes32ToString(_isFirst ? currentFirstHouseTicker : currentSecondHouseTicker);
    }
    
    /**
     * Get the open price for a house -> for a war specified by _warIndex
     **/
    function getHouseOpenPrice(uint256 _warIndex, bool _isFirst) public view returns(uint256){
        return wars[_warIndex].houses[_isFirst ? currentFirstHouseTicker : currentSecondHouseTicker].openPrice;
    }
    
    /**
     * Get the close price for a house -> for a war specified by _warIndex
     **/
    function getHouseClosePrice(uint256 _warIndex, bool _isFirst) public view returns(uint256){
        return wars[_warIndex].houses[_isFirst ? currentFirstHouseTicker : currentSecondHouseTicker].closePrice;
    }
    
    /**
     * Get the the number of tickets bought by the user -> for a war specified by _warIndex
     **/
    function getUserTickets(uint256 _warIndex) public view returns(uint256){
        return wars[_warIndex].users[msg.sender].ticketsBought;
    }
    
    /**
     * Get user (ticketsBought * ticketPrice) - user fees
     **/
    function getUserDoTxInBalance(uint256 _warIndex) public view returns(uint256){
        return getUserTickets(_warIndex).mul(getWarTicketPrice(_warIndex));
    }
    
     /**
     * Get the house the user pledged allegiance -> for a war specified by _warIndex
     **/
    function getUserHouse(uint256 _warIndex) public view returns(string memory){
        return bytes32ToString(wars[_warIndex].users[msg.sender].houseTicker);
    }
    
    /**
     * Get the fees spent by a user -> for a war specified by _warIndex
     **/
    function getUserFees(uint256 _warIndex) public view returns(uint256){
        return wars[_warIndex].users[msg.sender].fees;
    }
    
    function getFeesForSwitchHouse() public returns(uint256){
        return (getUserDoTxInBalance(currentWarIndex).mul(wars[currentWarIndex].warFeesPercent)).div(100);
    }
    
    /*****************************
            SETTER METHODS
    ******************************/
    
    /**
     * Set the select winner precision used for calculate the best house's performance
     **/
    function setSelectWinnerPrecision(uint256 _precision) public onlyOwner{
        selecteWinnerPrecision = _precision;
    }
    
    /**
     * Set Chainlink Oracle's address
     **/
    function setChainLinkOracleAddress(address _oracleAddress) public onlyOwner{
        ORACLE_ADDRESS = _oracleAddress;
    }
    
    /**
     * Set Chainlink Oracle's job id -> http get > uint256 job
     **/
    function setChainJobId(string memory _jobId) public onlyOwner{
        JOBID = _jobId;
    }
    
    /**
     * Set the amount of Link used to performe a call
     **/
    function setOraclePaymentAmount(uint256 _linkAmount) public onlyOwner{
        ORACLE_PAYMENT = _linkAmount;
    }

    /*****************************
            ADMIN METHODS
    ******************************/
    
    /**
     * Let owner withdraw DoTx fees (in particular to pay the costs generated by Chainlink)
     **/
    function withdrawFees() public onlyOwner returns(bool) {
        dotxToken.transfer(owner(), totalFees);
        
        totalFees = 0;
        
        return true;
    }
    
    /**
     * Let owner withdraw Link owned by the contract
     **/
    function withdrawLink() public onlyOwner{
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(owner(), link.balanceOf(address(this))), "Unable to transfer");
    }
    
    /****************************
            UTILS METHODS
    *****************************/
    
    /**
     * Convert string to bytes32
     **/
    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
    
        assembly {
            result := mload(add(source, 32))
        }
    }
    
    /**
     * Convert bytes32 to string
     **/
    function bytes32ToString(bytes32 x) private pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
    
    /**
     * A method to concat multiples string in one
     **/
    function append(string memory a, string memory b, string memory c, string memory d, string memory e) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }
    
    /**
     * Return true if the war is in its first day
     **/
    function isFirstDayForCurrentWar() view private returns(bool){
        //Update start time if failed
        return (now.sub(wars[currentWarIndex].startTime)) < SECONDS_IN_DAYS;
    }
    
    /**
     * Return the first house for the current war
     **/
    function getFirstHouse() private view returns(House memory){
        return wars[currentWarIndex].houses[currentFirstHouseTicker];
    }
    
    /**
     * Return the second house for the current war
     **/
    function getSecondHouse() private view returns(House memory){
        return wars[currentWarIndex].houses[currentSecondHouseTicker];
    }
    
    /**
     * Return user who call the contract right now
     **/
    function getCurrentUser() private view returns(User memory){
        return wars[currentWarIndex].users[msg.sender];
    }
    
    /**
     * Check if the house passed in parameter is in the current war
     **/
    function checkIfHouseInCompetition(string memory _houseTicker) private view returns(bool){
        //Check if house exists in current war
        bytes32 houseTicker = stringToBytes32(_houseTicker);
        return wars[currentWarIndex].houses[houseTicker].houseTicker == houseTicker;
    }
    
    /**
     * Calculate the reward for the current user
     **/
    function getCurrentReward(string memory _winningHouse) public view returns(uint256){
        bytes32 winningHouse = stringToBytes32(_winningHouse);
        //Losing house
        bytes32 losingHouse = currentFirstHouseTicker == winningHouse ? currentSecondHouseTicker : currentFirstHouseTicker;
        //Price per ticket for this war
        uint256 ticketPrice = getWarTicketPrice(currentWarIndex);
        
        //Total DoTx in house's balance
        uint256 totalDoTxWinningHouse = wars[currentWarIndex].houses[winningHouse].ticketsBought.mul(ticketPrice);
        uint256 totalDoTxLosingHouse = wars[currentWarIndex].houses[losingHouse].ticketsBought.mul(ticketPrice);
        
        uint256 dotxUserBalance = getUserDoTxInBalance(currentWarIndex);
        
        uint256 precision = 10000;
        uint256 percent = (dotxUserBalance.mul(precision)).div(totalDoTxWinningHouse);
        //Reward for this user
        uint256 reward = (totalDoTxLosingHouse.mul(percent)).div(precision);
        
        return reward;
    }
}
