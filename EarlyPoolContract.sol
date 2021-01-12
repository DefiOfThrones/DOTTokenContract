pragma solidity 0.6.12;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";

interface IDoTxTokenContract{
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
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
    address public dotxGameAddress;

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
        require(_owner == _msgSender() || dotxGameAddress == _msgSender() || dotxGameAddress == address(0), "Ownable: caller is not the owner");
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
 * @title DeFi Of Thrones Early Pool Contract
 * @author Maxime Reynders - DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract EarlyPoolContract is Ownable {
    using SafeMath for uint256;
    
    //User struct, each war contains a map of users
    //Each user can pledge allegiance to a house, buy tickets and switch house by paying fees (x% of its bought tickets)
    struct Pool {
        uint256 startTime;
        uint256 duration;
        uint256 startStakePeriod;
        uint256 balance;
        uint256 staked;
        uint256 totalTickets;
        //User Balance
        mapping(address => User) users;
    }
    
    struct User {
        uint256 userTickets;
        uint256 stakedAmount;
        uint256 farmingBag;
        uint256 startTime;
        uint256 stakeIndex;
        bool withdraw;
    }
    
    struct Staking {
        uint256 duration;
        uint256 percentage;
    }
    
    //Map of Pools 
    mapping(uint256 => Pool) public pools;
    Staking[3] staking;
    uint public longNightIndex;
    
    IDoTxTokenContract private doTxToken;
    
    uint256 public rewardPrecision = 100000000;

    constructor(address dotxTokenAddress) public {
        doTxToken = IDoTxTokenContract(dotxTokenAddress);
        
        staking[0] = Staking(2678400, 2123);
        staking[1] = Staking(5356800, 10192);
        staking[2] = Staking(8035200, 25479);
    }
    
    function startLongNight(uint256 _duration, uint256 _stakePeriod) public onlyOwner{
        //Staking period must be finished
        require(isStartStakingPeriodFinished(longNightIndex), "Staking period not finished");

        longNightIndex++;
        //Start long night
        pools[longNightIndex].startTime = now;
        pools[longNightIndex].duration = _duration;
        pools[longNightIndex].startStakePeriod = _stakePeriod;
        //Add remaining dotx from previous war to current balance
        pools[longNightIndex].balance = pools[longNightIndex].balance.add(pools[longNightIndex - 1].balance.sub(pools[longNightIndex - 1].staked));
    }
    
    /**
    * AddEarlyDoTx - When an user buy ticket in war
    * Parameters :
    * _dotx Number of DoTx
    * _longNightIndex Long night index
    * _user User address
    **/
    function addEarlyTickets(uint256 _dotx, uint256 _index, address _user) public onlyOwner{
        uint256 index = isLongNightFinished(_index) ? _index.add(1) : _index;
        pools[index].users[_user].userTickets = pools[index].users[_user].userTickets.add(_dotx);
        pools[index].totalTickets = pools[index].totalTickets.add(_dotx);
    }
    
    /**
    * AddDoTxToPool - Add DoTx to a pool
    * Parameters :
    * _dotx Number of DoTx
    * _longNightIndex Long night index
    **/
    function addDoTxToPool(uint256 _dotx, uint256 _index) external onlyOwner{
        uint256 index = isLongNightFinished(_index) ? _index.add(1) : _index;
        pools[index].balance = pools[index].balance.add(_dotx);
       
        doTxToken.transferFrom(msg.sender, address(this), _dotx);
    }
    
    function startStaking(uint256 _stakingIndex, uint256 _index) public{
        //Long night must be finished
        require(isLongNightFinished(_index), "Long night not finished");
        //Staking period must not be finished
        require(!isStartStakingPeriodFinished(_index), "Start staking period finished");
        
        //Get farming bag
        pools[_index].users[msg.sender].farmingBag = getFarmingBag(_index, msg.sender);
        
        //Calculate DoTx to stake -> DoTx in farming bag / Staking Period ROI % = DoTx to stake
        pools[_index].users[msg.sender].stakedAmount = getDoTxToStake(_stakingIndex, pools[_index].users[msg.sender].farmingBag);
        pools[_index].users[msg.sender].stakeIndex = _index;
        pools[_index].users[msg.sender].startTime = now;
        
        //Add farmingBag to balance staked
        pools[_index].staked = pools[_index].staked.add(pools[_index].users[msg.sender].farmingBag);
        
        require(doTxToken.transferFrom(msg.sender, address(this), pools[_index].users[msg.sender].stakedAmount));
    }
    
    function withdrawStakes(uint256[] memory _indexes) public{
        for(uint256 i=0; i < _indexes.length; i++){
            withdrawStake(_indexes[i]);
        }
    }
    
    function withdrawStake(uint256 _index) public{
        require(isStakingFinished(_index, msg.sender), "Staking not finished");
        require(!pools[_index].users[msg.sender].withdraw, "Already withdraw");
        
        pools[_index].users[msg.sender].withdraw = true;
        
        doTxToken.transfer(msg.sender, pools[_index].users[msg.sender].stakedAmount + pools[_index].users[msg.sender].farmingBag);
    }
    
    function getFarmingBag(uint256 _index, address _userAddress) public view returns(uint256){
        uint256 poolBalance = pools[_index].balance;
        uint256 usersTickets = pools[_index].totalTickets;
        uint256 userTickets = pools[_index].users[_userAddress].userTickets;
        
        //Calculate farming bag
        uint256 percent = (userTickets.mul(rewardPrecision)).div(usersTickets);
        return (poolBalance.mul(percent)).div(rewardPrecision);
    }
    
    function getDoTxToStake(uint256 _stakingIndex, uint256 _farmingBagDoTx) public view returns(uint256) {
        return (_farmingBagDoTx.mul(rewardPrecision)).div(staking[_stakingIndex].percentage).mul(10000).div(rewardPrecision);
    }
    
    function setDoTxGame(address gameAddress) public onlyOwner{
        dotxGameAddress = gameAddress;
    }
    
    function isLongNightFinished(uint256 _index) public view returns(bool) {
        return pools[_index].startTime.add(pools[_index].duration) < now;
    }
    
    function isStartStakingPeriodFinished(uint256 _index) public view returns(bool) {
        return pools[_index].startTime.add(pools[_index].duration).add(pools[_index].startStakePeriod) < now;
    }
    
    function isStakingFinished(uint256 _index, address userAddress) public view returns(bool) {
        User memory user = pools[_index].users[userAddress];
        return user.startTime.add(staking[user.stakeIndex].duration) < now;
    }
    
    function setupStaking(uint256 _index, uint256 _duration, uint256 _percentage) public{
        staking[_index] = Staking(_duration, _percentage);
    }
    
    function getLongNightIndex() external view returns(uint256){
        return longNightIndex;
    }
}
