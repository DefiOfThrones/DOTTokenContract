pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/IDotTokenContract.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";
import "github.com/smartcontractkit/chainlink/evm-contracts/src/v0.6/ChainlinkClient.sol";

interface IDoTxLib{
    function queryChainLinkPrice(string calldata _fsym, string calldata _fsymId, int256 _multiplicator, bytes4 _selector) external;
    function fetchFirstDayPrices(string calldata firstHouseTicker, string calldata secondHouseTicker, string calldata firstHouseId, string calldata secondHouseId, int256 multiplicator) external;
    function fetchLastDayPrices(string calldata firstHouseTicker, string calldata currentSecondHouseTicker, string calldata firstHouseId, string calldata secondHouseId, int256 multiplicator) external;
    function setDoTxGame(address gameAddress) external;
    function stringToBytes32(string calldata source) external pure returns (bytes32 result);
    function bytes32ToString(bytes32 x) external pure returns (string memory);
    function append(string calldata a, string calldata b, string calldata c, string calldata d, string calldata e) external pure returns (string memory);
    function calculateHousePerf(int256 open, int256 close, int256 precision) external pure returns(int256);
}

contract Context {
    constructor () internal { }

    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    address public dotxLibAddress;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    modifier onlyOwnerOrDoTxLib() {
        require(_owner == _msgSender() || dotxLibAddress == _msgSender(), "Ownable: caller is not the owner or the lib");
        _;
    }
    
    modifier onlyDoTxLib() {
        require(dotxLibAddress == _msgSender(), "Ownable: caller is not the owner or the lib");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/**
 * @title DeFi Of Thrones Game Contract
 * @author Maxime Reynders - DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract DoTxGameContract is Ownable {
    using SafeMath for uint256;
    
    //Debug purpose must be false if deployed over local VM - Must be deleted for production
    bool isOnChain = true;
    uint256 constant public MIN_ALLOWANCE = 1000000000000000000000000000000;
    uint256 constant public SECONDS_IN_DAYS = 86400;
    address constant public BURN_ADDRESS = 0x0000000000000000000000000000000000000001;

    //War struct, for each war a War variable will be created 
    struct War {
        uint256 startTime;
        uint256 duration;
        uint256 ticketPrice;
        uint256 purchasePeriod;
        bytes32 winningHouse;
        uint256 ticketsBought;
        uint256 warFees;
        uint256 warFeesPercent;
        int256 multiplicator;
        bytes32 firstHouseTicker;
        bytes32 secondHouseTicker;
        mapping(address => User) users;
        mapping(bytes32 => House)  houses;
    }
    //House struct, each war contains an map of 2 houses (could be more ine the future)
    struct House {
        bytes32 houseTicker;
        bytes32 houseId;
        uint256 openPrice;
        uint256 closePrice;
        uint256 ticketsBought;
        uint256 dotxToBurn;
        uint256 dotxToSendInStaking;
        uint256 totalUsers;
    }
    //User struct, each war contains a map of users
    //Each user can pledge allegiance for a house, buy tickets and switch house by paying fees
    struct User {
        bytes32 houseTicker;
        uint256 ticketsBought;
        uint256 fees;
        bool rewardClaimed;
    }
    
    //DOTX Contract Address
    IDotTokenContract private dotxToken;
    //DOTX Game lib
    IDoTxLib private dotxLib;
    address stakingAddress = address(0x1c2206f3115CaC3750acCb899d18d50b774C2f21);
    
    //Map of Wars 
    mapping(uint256 => War) public wars;
    //Map of players address
    mapping(uint256 => address[]) public players;
    //Index of the current war
    uint256 public currentWarIndex = 0;
    //First house for the current war
    bytes32 currentFirstHouseTicker;
    //Second house for the current war
    bytes32 currentSecondHouseTicker;

    
    //GENERAL VARS
    //Total fees paid by users
    uint256 public totalFees;
    //Precision for the select winner calculation
    uint256 public selecteWinnerPrecision = 100000;
    
    //BURN VARS
    //% of DoTx burn from losing house
    uint256 public burnPercentage = 5;
    //% of DoTx to send in staking address from losing house
    uint256 public stakingPercentage = 5;
    
    //EVENTS
    event WarStarted();
    event TicketBought(string house);
    event SwitchHouse(string from, string to);
    event openPriceFetched();
    event closePriceFetched();
    event eventTx(string txType);
    
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
        require(now.sub(wars[currentWarIndex].startTime) < wars[currentWarIndex].purchasePeriod,
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
        
        string memory firstHouseT = "COMP";
        string memory firstHouseId = "compound-governance-token";
        string memory secondHouseT = "TEND";
        string memory secondHouseId = "tendies";
        
        wars[currentWarIndex] = War(now, 300, 10000000000000000000, 250, 0, 0, 0, 1, 10000, stringToBytes32(firstHouseT), stringToBytes32(secondHouseT));
        wars[currentWarIndex].houses[stringToBytes32(firstHouseT)] = House(stringToBytes32(firstHouseT), stringToBytes32(firstHouseId), 1300000, 0, 0, 0, 0, 0);
        wars[currentWarIndex].houses[stringToBytes32(secondHouseT)] = House(stringToBytes32(secondHouseT), stringToBytes32(secondHouseId), 2000, 0, 0, 0, 0, 0);
        
        currentFirstHouseTicker = stringToBytes32(firstHouseT);
        currentSecondHouseTicker = stringToBytes32(secondHouseT);
    }
    
    /**
     * Game contract constructor
     * Just pass the DoTx contract address in parameter
     **/
    constructor(address dotxTokenAddress, address dotxLibAddr, bool setupAddressInLib) public {
        //Implement DoTx contract interface by providing address
        dotxToken = IDotTokenContract(dotxTokenAddress);
        
        setDoTxLib(dotxLibAddr, setupAddressInLib);
        
        //Delete for production
        //mockData();
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
     * purchasePeriod Number of seconds where the users can buy tickets from the starting date
     * _warFeesPercent How many % fees it will cost to user to switch house 
     * _multiplicator Precision of the prices receive from WS
     **/
    function startWar(string memory _firstHouseTicker, string memory _secondHouseTicker, string memory _firstHouseId, string memory _secondHouseId, 
    uint256 _duration, uint256 _ticketPrice, uint256 _purchasePeriod, uint256 _warFeesPercent, int256 _multiplicator) 
    public onlyOwner onlyIfCurrentWarFinished returns(bool) {
        currentWarIndex++;
        //Create war  
        currentFirstHouseTicker = stringToBytes32(_firstHouseTicker);
        currentSecondHouseTicker = stringToBytes32(_secondHouseTicker);
        wars[currentWarIndex] = War(now, _duration, _ticketPrice, _purchasePeriod, 0, 0, 0, _warFeesPercent, _multiplicator, currentFirstHouseTicker, currentSecondHouseTicker);
        
        //Create first house
        wars[currentWarIndex].houses[currentFirstHouseTicker] = House(currentFirstHouseTicker, stringToBytes32(_firstHouseId), 0, 0, 0, 0, 0, 0);
        //Create second house
        wars[currentWarIndex].houses[currentSecondHouseTicker] = House(currentSecondHouseTicker, stringToBytes32(_secondHouseId), 0, 0, 0, 0, 0, 0);
        
        emit WarStarted();
        
        fetchFirstDayPrices();
        
        return true;
    }
    
     /**
     * Buy ticket(s) for the current war - only if tickets are purchasable -> purchasePeriod
     * Parameters :
     * _houseTicker House ticker 
     * _numberOfTicket The number of tickets the user wants to buy
     **/
    function buyTickets(string memory _houseTicker, uint _numberOfTicket) public onlyIfTicketsPurchasable returns(bool) {
        War storage war = wars[currentWarIndex];
        
        //Check if user has enough DoTx to spend
        uint256 userAmountSpend = getWarTicketPrice(currentWarIndex).mul(_numberOfTicket);
        
        //Check if house is in competition
        bytes32 houseTicker = stringToBytes32(_houseTicker);
        require(checkIfHouseInCompetition(_houseTicker), "House not in competition");
        
        //Allow user to only buy tickets for one single House
        bytes32 userHouseTicker = getCurrentUser().houseTicker;
        require(userHouseTicker == houseTicker || userHouseTicker == 0, "You can't buy tickets for the other house - You can switch if you want");
        
        
        if(war.users[msg.sender].ticketsBought == 0){
            //Count unique user
            war.houses[houseTicker].totalUsers = war.houses[houseTicker].totalUsers + 1;
            //Add player
            players[currentWarIndex].push(msg.sender);
        }

        //Update user tickets
        war.users[msg.sender].houseTicker = houseTicker;
        war.users[msg.sender].ticketsBought = getCurrentUser().ticketsBought.add(_numberOfTicket);
        
        //Increase tickets bought for the house
        war.houses[houseTicker].ticketsBought = war.houses[houseTicker].ticketsBought.add(_numberOfTicket);
        //Calculate tickets remaining after burn
        uint256 ticketsBoughtValueDoTx = war.houses[houseTicker].ticketsBought * getWarTicketPrice(currentWarIndex);
        war.houses[houseTicker].dotxToBurn = calculatePercentage(ticketsBoughtValueDoTx, burnPercentage);
        //Set staking amount
        war.houses[houseTicker].dotxToSendInStaking = calculatePercentage(ticketsBoughtValueDoTx, stakingPercentage);
        
        //Increase total tickets bought
        war.ticketsBought = war.ticketsBought.add(_numberOfTicket);
        
        //Propagate TicketBought event
        emit TicketBought(_houseTicker);
        
        //Transfer DoTx
        if(isOnChain){
            return dotxToken.transferFrom(msg.sender, address(this), userAmountSpend);
        }else{
            return true;
        }
    }
    
    /**
     * Switch house for the user - only if tickets are purchasable -> purchasePeriod
     * Parameters :
     * _fromHouseTicker Current house user pledged allegiance 
     * _toHouseTicker the house user wants to join
     **/
    function switchHouse(string memory _fromHouseTicker, string memory _toHouseTicker) public onlyIfTicketsPurchasable returns(bool) {
        War storage war = wars[currentWarIndex];
        //Check if houses are in competition
        require(checkIfHouseInCompetition(_fromHouseTicker), "House not in competition");
        require(checkIfHouseInCompetition(_toHouseTicker), "House not in competition");
        
        bytes32 fromHouseTicker = stringToBytes32(_fromHouseTicker);
        bytes32 toHouseTicker = stringToBytes32(_toHouseTicker);
        
        //Check if user belongs to _fromHouse 
        require(getCurrentUser().houseTicker == fromHouseTicker, "User doesn't belong to fromHouse");
        
        //Requires at least one ticket bought
        uint256 ticketsBoughtByUser = getCurrentUser().ticketsBought;
        require(ticketsBoughtByUser > 0, "User can't switch without tickets");
        
        //Switch house for user
        war.users[msg.sender].houseTicker = toHouseTicker;
        
        //Update fromHouse tickets
        uint256 fromHouseTickets = getTicketsBoughtForHouse(currentWarIndex, _fromHouseTicker);
        war.houses[fromHouseTicker].ticketsBought = fromHouseTickets.sub(ticketsBoughtByUser);
        uint256 ticketsBoughtUpTodate = war.houses[fromHouseTicker].ticketsBought;
        
        uint256 ticketsValueInDoTx = ticketsBoughtUpTodate.mul(getWarTicketPrice(currentWarIndex));
        war.houses[fromHouseTicker].dotxToBurn = calculatePercentage(ticketsValueInDoTx, burnPercentage);
        //Set staking amount
        war.houses[fromHouseTicker].dotxToSendInStaking = calculatePercentage(ticketsValueInDoTx, stakingPercentage);
        
        //Update toHouse tickets
        uint256 toHouseTickets = getTicketsBoughtForHouse(currentWarIndex, _toHouseTicker);
        war.houses[toHouseTicker].ticketsBought = toHouseTickets.add(ticketsBoughtByUser);
        ticketsBoughtUpTodate = war.houses[toHouseTicker].ticketsBought;
        
        uint256 ticketsBoughtUpTodateValueInDoTx = ticketsBoughtUpTodate.mul(getWarTicketPrice(currentWarIndex));
        war.houses[toHouseTicker].dotxToBurn = calculatePercentage(ticketsBoughtUpTodateValueInDoTx, burnPercentage);
        //Set staking amount currently == burn amount
        war.houses[toHouseTicker].dotxToSendInStaking = calculatePercentage(ticketsBoughtUpTodateValueInDoTx, stakingPercentage);
        
        //Update unique users
        war.houses[fromHouseTicker].totalUsers = war.houses[fromHouseTicker].totalUsers - 1;
        war.houses[toHouseTicker].totalUsers = war.houses[toHouseTicker].totalUsers + 1;
        
        //Update user fees
        uint256 feesToBePaid = getFeesForSwitchHouse(msg.sender);
        //Update fees fot user
        war.users[msg.sender].fees = getCurrentUser().fees.add(feesToBePaid);
        //Update war fees
        war.warFees = war.warFees.add(feesToBePaid);
        //Update total fees
        totalFees = totalFees.add(feesToBePaid);
        
        emit SwitchHouse(_fromHouseTicker, _toHouseTicker);
        
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
        //Only claim reward one times
        require(wars[currentWarIndex].users[msg.sender].rewardClaimed == false, "You already claimed your reward");
        
        //A winner house must be elected
        require(wars[currentWarIndex].winningHouse != 0, "Winner not elected");
        
        //Check if user has at least one ticketsBought 
        require(wars[currentWarIndex].users[msg.sender].ticketsBought > 0, "User doesn't have ticket");
        
        //Check if user belongs to winning house
        bytes32 winningHouse = wars[currentWarIndex].winningHouse;
        require(getCurrentUser().houseTicker == winningHouse, "User doesn't belong to winning house");
        
        //DoTx in user balance
        uint256 reward = getCurrentReward(bytes32ToString(winningHouse), msg.sender);
        
        if(isOnChain){
            dotxToken.transfer(msg.sender, reward.add(getUserDoTxInBalance(currentWarIndex, msg.sender)));
        }
        
        //Set rewardClaimed to true
        wars[currentWarIndex].users[msg.sender].rewardClaimed = true;
        
        emit eventTx("CLAIM");
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
        
        string memory firstHouse = bytes32ToString(currentFirstHouseTicker);
        string memory secondHouse = bytes32ToString(currentSecondHouseTicker);
        
        dotxLib.fetchFirstDayPrices(firstHouse, secondHouse, getHouseId(currentWarIndex, firstHouse), getHouseId(currentWarIndex, secondHouse), wars[currentWarIndex].multiplicator);
    }

    /**
     * Fetch the prices for the 2 houses the last day for the current war
     **/
    function fetchLastDayPrices() public onlyOwner onlyIfCurrentWarFinished {
        require(getFirstHouse().closePrice == 0 && getSecondHouse().closePrice == 0, "Close prices already fetched");
        
        string memory firstHouse = bytes32ToString(currentFirstHouseTicker);
        string memory secondHouse = bytes32ToString(currentSecondHouseTicker);
        
        dotxLib.fetchLastDayPrices(firstHouse, secondHouse, getHouseId(currentWarIndex, firstHouse), getHouseId(currentWarIndex, secondHouse), wars[currentWarIndex].multiplicator);
    }
    
    /**
     * Elect the winner based on open prices & close prices
     **/
    function selectWinner() public onlyOwner onlyIfCurrentWarFinished onlyIfPricesFetched {
        require(wars[currentWarIndex].winningHouse == 0, "Winner already selected");
        
        int256 fstHOpen = int256(getFirstHouse().openPrice);
        int256 fstHClose = int256(getFirstHouse().closePrice);
        int256 sndHOpen = int256(getSecondHouse().openPrice);
        int256 sndHClose = int256(getSecondHouse().closePrice);
        int256 precision = int256(selecteWinnerPrecision);
        
        int256 firstHousePerf =  dotxLib.calculateHousePerf(fstHOpen, fstHClose, precision);
        int256 secondHousePerf = dotxLib.calculateHousePerf(sndHOpen, sndHClose, precision);
        
        //Set winner house
        wars[currentWarIndex].winningHouse = firstHousePerf > secondHousePerf ? currentFirstHouseTicker : currentSecondHouseTicker;
        bytes32 losingHouse = firstHousePerf > secondHousePerf ? currentSecondHouseTicker : currentFirstHouseTicker;
        
        /*
        BURN X% OF LOSING HOUSE'S DOTX
        */
        emit eventTx("BURN");
        dotxToken.transfer(BURN_ADDRESS, wars[currentWarIndex].houses[losingHouse].dotxToBurn);
        
        /*
        BURN X% OF LOSING HOUSE'S DOTX TO STAKING ADDRESS
        */
        emit eventTx("STAKING");
        dotxToken.transfer(stakingAddress, wars[currentWarIndex].houses[losingHouse].dotxToSendInStaking);
    }

    
    /*******************************
            CHAINLINK METHODS
    ********************************/
    
    /**
     * Handler method called by Chainlink for the first house open price 
     **/
    function firstHouseOpen(uint256 _price) external onlyDoTxLib {
        wars[currentWarIndex].houses[currentFirstHouseTicker].openPrice = _price;
        openPriceEvent();
    }
    /**
     * Handler method called by Chainlink for the second house open price 
     **/
    function secondHouseOpen(uint256 _price) external onlyDoTxLib {
        wars[currentWarIndex].houses[currentSecondHouseTicker].openPrice = _price;
        openPriceEvent();
    }
    /**
     * Handler method called by Chainlink for the first house close price 
     **/
    function firstHouseClose(uint256 _price) external onlyDoTxLib {
        wars[currentWarIndex].houses[currentFirstHouseTicker].closePrice = _price;
        closePriceEvent();
    }
    /**
     * Handler method called by Chainlink for the second house close price 
     **/
    function secondHouseClose(uint256 _price) external onlyDoTxLib {
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
    function getUserTickets(uint256 _warIndex, address userAddress) public view returns(uint256){
        return wars[_warIndex].users[userAddress].ticketsBought;
    }
    
    /**
     * Get user (ticketsBought * ticketPrice) - user fees
     **/
    function getUserDoTxInBalance(uint256 _warIndex, address userAddress) public view returns(uint256){
        return getUserTickets(_warIndex, userAddress).mul(getWarTicketPrice(_warIndex));
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
    
    
    function getFeesForSwitchHouse(address userAddress) public view returns(uint256){
        return (getUserDoTxInBalance(currentWarIndex, userAddress).mul(wars[currentWarIndex].warFeesPercent)).div(100);
    }
    
    /**
     * Returns house id specified by _warIndex
     **/
    function getHouseId(uint256 _warIndex, string memory houseTicker) public view returns(string memory){
        return bytes32ToString(wars[_warIndex].houses[stringToBytes32(houseTicker)].houseId);
    }
    
    /**
     * Returns the current user
     **/
    function getUser(uint256 _warIndex, address userAddress) public view returns(User memory){
        return wars[_warIndex].users[userAddress];
    }
    
    /**
     * Return house forrent specific war
     **/
    function getHouse(uint256 _warIndex, string memory houseTicker) public view returns(House memory){
        return wars[_warIndex].houses[stringToBytes32(houseTicker)];
    }
    
    /**
     * Return players addresses for the specific war
     **/
    function getPlayers(uint256 _warIndex) public view returns(address[] memory){
        return players[_warIndex];
    }

    /*****************************
            ADMIN METHODS
    ******************************/
    
    /**
     * Set the select winner precision used for calculate the best house's performance
     **/
    function setSelectWinnerPrecision(uint256 _precision) public onlyOwner{
        selecteWinnerPrecision = _precision;
    }

    /**
     * Set burn % of the losing house's DoTx to burn
     **/
    function setBurnPercentage(uint256 _burnPercentage) public onlyOwner{
        burnPercentage = _burnPercentage;
    }
    
     /**
     * Set staking % of the losing house's DoTx to send
     **/
    function setStakingPercentage(uint256 _stakingPercentage) public onlyOwner{
        stakingPercentage = _stakingPercentage;
    }
    
    /**
     * Let owner withdraw DoTx fees (in particular to pay the costs generated by Chainlink)
     **/
    function withdrawFees() public onlyOwner returns(bool) {
        dotxToken.transfer(owner(), totalFees);
        
        totalFees = 0;
        
        return true;
    }
    
    /**
     * Let owner set the DoTxLib address
     **/
    function setDoTxLib(address dotxLibAddr, bool setupAddressInLib) public onlyOwner {
        //DOTX lib mainly uses for Chainlink
        dotxLibAddress = dotxLibAddr;
        dotxLib = IDoTxLib(dotxLibAddress);
        if(setupAddressInLib){
            dotxLib.setDoTxGame(address(this));
        }
    }
    
    /**
     * Let owner update stakingAddress
     **/
    function setStakingAddress(address stakingAdr) public onlyOwner returns(bool) {
        stakingAddress = stakingAdr;
    }

    /****************************
            UTILS METHODS
    *****************************/
    
    /**
     * Convert string to bytes32
     **/
    function stringToBytes32(string memory source) private view returns (bytes32 result) {
        return dotxLib.stringToBytes32(source);
    }
    
    /**
     * Convert bytes32 to string
     **/
    function bytes32ToString(bytes32 x) private view returns (string memory) {
        return dotxLib.bytes32ToString(x);
    }
    
    /**
     * A method to concat multiples string in one
     **/
    function append(string memory a, string memory b, string memory c, string memory d, string memory e) internal view returns (string memory) {
        return dotxLib.append(a,b, c, d, e);
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
    function getCurrentReward(string memory _winningHouse, address userAddress) public view returns(uint256){
        bytes32 winningHouse = stringToBytes32(_winningHouse);
        //Losing house
        bytes32 losingHouse = currentFirstHouseTicker == winningHouse ? currentSecondHouseTicker : currentFirstHouseTicker;
        //Price per ticket for this war
        uint256 ticketPrice = getWarTicketPrice(currentWarIndex);
        
        //Total DoTx in house's balance
        uint256 totalDoTxWinningHouse = wars[currentWarIndex].houses[winningHouse].ticketsBought.mul(ticketPrice);
        uint256 totalDoTxLosingHouse = wars[currentWarIndex].houses[losingHouse].ticketsBought.mul(ticketPrice).sub(wars[currentWarIndex].houses[losingHouse].dotxToBurn).sub(wars[currentWarIndex].houses[losingHouse].dotxToSendInStaking);
        
        uint256 dotxUserBalance = getUserDoTxInBalance(currentWarIndex, userAddress);
        
        uint256 precision = 10000;
        uint256 percent = (dotxUserBalance.mul(precision)).div(totalDoTxWinningHouse);
        //Reward for this user
        uint256 reward = (totalDoTxLosingHouse.mul(percent)).div(precision);
        
        return reward;
    }
    
    /*
    * CALCULATE BURN OR STAKING %
    */
    function calculatePercentage(uint256 amount, uint256 percentage) public view returns(uint256){
        return amount.mul(selecteWinnerPrecision).mul(percentage).div(100).div(selecteWinnerPrecision);
    }
}
