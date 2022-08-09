pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

pragma solidity 0.6.12;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";

interface IDotTokenContract{
  function balanceOf(address account) external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
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
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IDotxGameContract{
    struct War {
        uint256 startTime;
        uint256 duration;
        uint256 ticketPrice;
        uint256 purchasePeriod;
        bytes32 winningHouse;
        uint256 warFeesPercent;
        int256 multiplicator;
        uint256 burnPercentage;
        House firstHouse;
        House secondHouse;
    }

    struct User {
        bytes32 houseTicker;
        uint256 ticketsBought;
        bool rewardClaimed;
    }

    struct House {
        bytes32 houseTicker;
        bytes32 houseId;
        uint256 openPrice;
        uint256 closePrice;
        uint256 ticketsBought;
    }
    
    function getCurrentReward(bytes32 _winningHouse, address userAddress, uint256 warIndex) external view returns(uint256);
    function getCurrentRewardString(string memory _winningHouse, address userAddress, uint256 warIndex) external view returns(uint256);
    function wars(uint256 index) external view returns(War memory);
    function getUser(uint256 _warIndex, address userAddress) external view returns(User memory);
}

contract DoTxGameProxyContract is Ownable{
    using SafeMath for uint256;
    //GAME CONTRACT
    IDotxGameContract private gameContract;
    address public dotxGameContractAddress;
    
    //War struct, for each war a War variable will be created 
    
    //House struct, each war contains an map of 2 houses
    struct House {
        bytes32 houseTicker;
        bytes32 houseId;
        uint256 openPrice;
        uint256 closePrice;
        uint256 ticketsBought;
    }
    //User struct, each war contains a map of users
    //Each user can pledge allegiance to a house, buy tickets and switch house by paying fees (x% of its bought tickets)

    
    //BURN STAKING INFORMATION
    struct BurnStake {
        uint256 firstHouseBurnDoTx;
        uint256 secondHouseBurnDoTx;
    }
    
    struct UserStats {
        uint256 warIndex;
        uint256 duration;
        uint256 reward;
        uint256 spent;
        uint256 startTime;
        uint256 vested;
        string houseTicker;
    }
    
    struct UserLeader {
        uint256 warIndex;
        uint256 reward;
        uint256 potentialReward;
        uint256 spent;
        string houseTicker;
        string winningHouse;
    }
    
    constructor(address _dotxGameContractAddress) public {
        setDoTxGameContract(_dotxGameContractAddress);
    }

    
    function getUserStats(address _userAddress, uint256 min, uint256 max) public view returns (UserStats[] memory){
        uint256 count = (max - min) + 1;
        UserStats[] memory stats = new UserStats[](count);
        uint256 i = min;
        uint256 index = 0;
        while(index < count){

            IDotxGameContract.User memory user = gameContract.getUser(i, _userAddress);
            IDotxGameContract.War memory war = gameContract.wars(i);
            string memory house = bytes32ToString(user.houseTicker);
            uint256 reward = gameContract.getCurrentRewardString(house, _userAddress, i);
            uint spent = user.ticketsBought.mul(war.ticketPrice);
            
            stats[index] = (UserStats(i, 
            war.duration, 
            reward, 
            spent, 
            war.startTime,
            user.rewardClaimed ? spent + reward : 0,
            house));
            
            i++;
            index++;
        }
        return stats;
    }
    
    function getUserLeader(uint256 warIndex, address _userAddress) public view returns (UserLeader memory){

        IDotxGameContract.User memory user = gameContract.getUser(warIndex, _userAddress);
        IDotxGameContract.War memory war = gameContract.wars(warIndex);
        string memory house = bytes32ToString(user.houseTicker);
        uint256 reward = gameContract.getCurrentRewardString(house, _userAddress, warIndex);
        uint spent = user.ticketsBought.mul(war.ticketPrice);
        
        UserLeader memory leader = (UserLeader(warIndex, 
        user.houseTicker == war.winningHouse ? reward : 0,
        reward,
        spent, 
        house,
        bytes32ToString(war.winningHouse)));
            
        return leader;
    }

    
    /**
     * Let owner set the DoTxGameContract address
     **/
    function setDoTxGameContract(address _dotxGameContractAddress) public onlyOwner {
        dotxGameContractAddress = _dotxGameContractAddress;
        gameContract = IDotxGameContract(_dotxGameContractAddress);
    }
    
     /**
     * Convert bytes32 to string
     **/
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