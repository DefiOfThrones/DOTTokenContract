pragma solidity ^0.6.6;
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/Ownable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/IDotTokenContract.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";
contract DoTGameContract is Ownable {
    using SafeMath for uint;
    struct War {
        bytes32 firstHouseTicker;
        bytes32 secondHouseTicker;
        uint256 duration;
        uint256 startTime;
        uint256 ticketPrice;
        uint256[] firstHousePrices;
        uint256[] secondHousePrices;
        uint winningHouse;
    }
    //DOTX Contract Address
    IDotTokenContract private dotxToken;
    //Array of Wars
    mapping(uint256 => War) public wars;
    //Index of the current war
    uint256 public currentWarIndex = 0;
    //EVENTS
    event WarStarted();
    //MODIFIERS
    modifier onlyIfCurrentWarFinished() {
        require(wars[currentWarIndex].startTime.add(wars[currentWarIndex].duration) > now || currentWarIndex == 0, "Current war not finished");
        _;
    }
    constructor(address dotxTokenAddress) public {
        dotxToken = IDotTokenContract(dotxTokenAddress);
    }
    /*
    WAR METHODS
    */
    function startWar(string memory _firstHouseTicker, string memory _secondHouseTicker, uint256 _duration, uint256 _ticketPrice, uint256 _startTime)
    public onlyOwner onlyIfCurrentWarFinished returns(bool) {
        currentWarIndex++;
        uint256[] memory prices1;
        uint256[] memory prices2;
        wars[currentWarIndex] = War(stringToBytes32(_firstHouseTicker),
        stringToBytes32(_secondHouseTicker),
        _duration,
        _ticketPrice,
        _startTime,
        prices1,
        prices2,
        99);
        emit WarStarted();
        return true;
    }
    /*
    PRICES METHODS
    */
    function getFirstDayPrices() public{
        //TODO Only if First day
    }
    function getLastDayPrices() public{
        //TODO Only if last day
    }
    /*
    CHAINLINK METHODS
    */
    function queryChainLinkPrices() private{
    }
    //Chainlink handler
    /*
    GETTER
    */
    function getWarHouseName(uint256 warIndex, bool isFirstHouse) view public returns(string memory) {
        War memory currentWar = wars[warIndex];
        string memory ticker = bytes32ToString(isFirstHouse ? currentWar.firstHouseTicker : currentWar.secondHouseTicker);
        return ticker;
    }
    function getWarDuration(uint256 warIndex) view public returns(uint256) {
        return wars[warIndex].duration;
    }
    function getWarStartTime(uint256 warIndex) view public returns(uint256) {
        return wars[warIndex].startTime;
    }
    function getWarTicketPrice(uint256 warIndex) view public returns(uint256) {
        return wars[warIndex].ticketPrice;
    }
    //TODO GET PRICES
    /*
    UTILS
    */
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
    function bytes32ToString(bytes32 x) public pure returns (string memory) {
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
}
