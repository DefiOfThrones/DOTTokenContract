// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IDoTxTokenContract{
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IDoTxNFTContract{
  function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IManaPoolLib{
    struct Stake {
        uint256 startTime;
        uint256 lpUniAmount;
        uint256 lpPancakeAmount;
        uint256 currentReward;
    }

    function getStake(address userAddress) external view returns(IManaPoolLib.Stake memory);
    function getStartTime(address user) external view returns(uint256);
    function getLpUniAmount(address user) external view returns(uint256);
    function getLpPancakeAmount(address user) external view returns(uint256);
    function getCurrentReward(address user) external view returns(uint256);
    function setStartTime(address user, uint256 value) external;
    function setLpUniAmount(address user, uint256 value) external;
    function setLpPancakeAmount(address user, uint256 value) external;
    function setCurrentReward(address user, uint256 value) external;
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
    address public pool2;
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
        require(_owner == _msgSender() 
        || dotxGameAddress == _msgSender() || dotxGameAddress == address(0)
        || pool2 == _msgSender(), "Ownable: caller is not the owner");
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
 * @title DeFi Of Thrones Mana Pool Contract
 * @author Maxime Reynders - DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract ManaPoolContract is Ownable {
    using SafeMath for uint256;
    
    //Stake NFT
    struct NFT {
        uint256 manaRequired;
    }
    
    IDoTxTokenContract private lpPancakeToken;
    IDoTxNFTContract private dotxNFT;
    IManaPoolLib private manaPoolLib;

    //Map of Stake per user address 
    
    mapping(uint256 => uint256) public manaBonus;
    //Early bonus
    uint256 public earlyBonusPercentage = 30;
     //Map of NFTs
    mapping(uint256 => NFT) public nfts;
    
    event AddTokens(uint256 valueInDoTx, address sender, bool isUni);
    event RemoveTokens(uint256 valueInDoTx, address sender, bool isUni);
    event ClaimNFT(uint256 _mana, address sender);
    event AddRewardFromTickets(uint256 warIndex, uint256 manaEarned, uint256 valueInDoTx, address sender, bool isEarly, uint256 warBonus, uint256 ticketsNumber);
    
    constructor(address dotxPancakeLp, address dotxNFTAddress, address manaPoolLibAddress) public {
        setDoTxPancakeLP(dotxPancakeLp);
        setDoTxNFT(dotxNFTAddress);
        setManaPoolLib(manaPoolLibAddress);
    }
    
    /**
    * addTokens - When an user wants to stake LP
    * Parameters :
    * _amountInWei Number of LP tokens
    **/
    function addTokens(uint256 _amountInWei, bool _isUni) public {
        if(getTotalLpTokens(msg.sender) != 0){
            manaPoolLib.setCurrentReward(msg.sender, getCurrentReward(msg.sender));
        }

        require(lpPancakeToken.transferFrom(msg.sender, address(this), _amountInWei), "Transfer failed");
        
        addRemoveLpTokens(_amountInWei, msg.sender, true, _isUni);
        manaPoolLib.setStartTime(msg.sender, now);
        
        emit AddTokens(_amountInWei, msg.sender, _isUni);
    }
    
    /**
    * addTokens - When an user wants to remove LP
    * Parameters :
    * _amountInWei Number of LP tokens
    **/
    function removeTokens(uint256 _amountInWei, bool _isUni) public {
        require((_isUni ? manaPoolLib.getLpUniAmount(msg.sender) : manaPoolLib.getLpPancakeAmount(msg.sender)) >= _amountInWei , "Not enought LP");
        
        manaPoolLib.setCurrentReward(msg.sender, getCurrentReward(msg.sender));
        manaPoolLib.setStartTime(msg.sender, now);
        addRemoveLpTokens(_amountInWei, msg.sender, false, _isUni);

        require(lpPancakeToken.transfer(msg.sender, _amountInWei), "Transfer failed");
        
        emit RemoveTokens(_amountInWei, msg.sender, _isUni);
    }
    
    /**
    * addRewardFromTickets - When an user buys tickets from the game
    * Parameters :
    * _amountInWei Number of LP tokens
    **/
    function addRewardFromTickets(uint256 _warIndex, uint256 _ticketsNumber, uint256 _dotxAmountInWei, address _userAddress, bool _isEarly) public onlyOwner{
        uint256 manaMultiplicator = manaBonus[_warIndex] != 0 ? manaBonus[_warIndex] : 1;
        uint256 newReward = _ticketsNumber.mul(manaMultiplicator).mul(1000000000000000000); // 1 ticket == (1 MANA * MANABONUS)
        newReward = newReward.add(_isEarly ? calculatePercentage(newReward, earlyBonusPercentage, 100000) : 0);// Early bonus
        
        manaPoolLib.setCurrentReward(_userAddress, getCurrentReward(_userAddress));
        manaPoolLib.setStartTime(_userAddress, now);
        manaPoolLib.setCurrentReward(_userAddress, manaPoolLib.getCurrentReward(_userAddress).add(newReward));
        
        emit AddRewardFromTickets(_warIndex, newReward, _dotxAmountInWei, _userAddress, _isEarly, manaMultiplicator, _ticketsNumber);
    }
    
    function getCurrentReward(address _userAddress) view public returns(uint256){
        uint256 diffTimeSec = now.sub(manaPoolLib.getStartTime(_userAddress));
        
        uint256 rewardPerSecond = calculateRewardPerSecond(getTotalLpTokens(_userAddress));
        
        //Previous reward + new reward
        uint256 newReward = diffTimeSec.mul(rewardPerSecond);
        return manaPoolLib.getCurrentReward(_userAddress).add(newReward);
    }
    
    function calculateRewardPerSecond(uint256 _amount) public pure returns(uint256){
        uint precision = 100000000000000000000000000;
        uint256 denom = 100000000;
        uint256 amount = _amount.mul(precision);
        uint256 b = 2000000000000000000000;
        uint256 a = 4;
        //f(x) = x / (ax + b)
        return amount.div(_amount.mul(a).add(b)).div(60).div(denom);
    }
    
    function getStake(address userAddress) public view returns(IManaPoolLib.Stake memory){
        return manaPoolLib.getStake(userAddress);
    }
    
    function setDoTxGame(address gameAddress) public onlyOwner{
        dotxGameAddress = gameAddress;
    }
    
    function setPool2(address _pool2) public onlyOwner{
        pool2 = _pool2;
    }
    
    function setManaBonus(uint256 _warIndex, uint256 _manaBonus) public onlyOwner{
        manaBonus[_warIndex] = _manaBonus;
    }
    
    function setDoTxPancakeLP(address dotxLpTokenAddress) public onlyOwner{
        lpPancakeToken = IDoTxTokenContract(dotxLpTokenAddress);
    }
    
    function setDoTxNFT(address dotxNFTAddress) public onlyOwner{
        dotxNFT = IDoTxNFTContract(dotxNFTAddress);
    }

    function setManaPoolLib(address manaPoolAddress) public onlyOwner{
        manaPoolLib = IManaPoolLib(manaPoolAddress);
    }
    
    function setearlyBonusPercentage(uint256 _earlyBonusPercentage) public onlyOwner{
        earlyBonusPercentage = _earlyBonusPercentage;
    }
    
    /*************
    NFT
    **************/
    
    /**
    * addNFTs - Owner can add NFTs & mana required to claim them
    * Parameters :
    * _ids : NFTs ids
    * _manaRequired : Mana required for each NFT
    **/
    function addNFTs(uint256[] memory _ids, uint256[] memory _manaRequired) public onlyOwner {
        for(uint256 i = 0; i < _ids.length; i++){
            dotxNFT.transferFrom(_msgSender(), address(this), _ids[i]);
            updateManaForNft(_ids[i], _manaRequired[i]);
        }
    }
    
    function updateManaForNft(uint256 _nftId, uint256 _manaRequired) public onlyOwner{
        nfts[_nftId].manaRequired = _manaRequired.mul(1000000000000000000);
    }
    
    /**
    * addNFTs - Owner can add NFTs & mana required to claim them
    * Parameters :
    * _ids : NFTs ids
    **/
    function transferNFT(uint256[] memory _ids, address _recipient) public onlyOwner{
        for(uint256 i = 0; i<_ids.length; i++){
            dotxNFT.transferFrom(address(this), _recipient, _ids[i]);
        }
    }
    
    /**
    * claimNFT - When an user want to use its MANA to claim NFT
    * Parameters :
    * _nftId : NFT id
    **/
    function claimNFT(uint256 _nftId) public{
        uint256 manaRequired = nfts[_nftId].manaRequired;
        
        manaPoolLib.setCurrentReward(_msgSender(), getCurrentReward(_msgSender()));
        require(manaPoolLib.getCurrentReward(_msgSender()) >= manaRequired, "Not enought MANA");
        
        manaPoolLib.setCurrentReward(_msgSender(), manaPoolLib.getCurrentReward(msg.sender).sub(manaRequired));
        manaPoolLib.setStartTime(_msgSender(), now);
        
        dotxNFT.transferFrom(address(this), _msgSender(), _nftId);
        
        emit ClaimNFT(manaRequired, _msgSender());
    }
    
    /**
    * getManaForNFT - Return mana required for NFTs
    * Parameters :
    * _ids : NFTs ids
    **/
    function getManaForNFT(uint256[] memory _ids) public view returns(uint256[] memory){
        uint256[] memory result = new uint256[](_ids.length);
        for(uint256 i = 0; i<_ids.length; i++){
            result[i] = nfts[_ids[i]].manaRequired;
        }
        
        return result;
    }
    
    function calculatePercentage(uint256 amount, uint256 percentage, uint256 selecteWinnerPrecision) public pure returns(uint256){
        return amount.mul(selecteWinnerPrecision).mul(percentage).div(100).div(selecteWinnerPrecision);
    }
    
    function getTotalLpTokens(address _user) public view returns(uint256){
        return manaPoolLib.getLpUniAmount(_user).add(manaPoolLib.getLpPancakeAmount(_user));
    }
    
    function addRemoveLpTokens(uint256 _amountInWei, address _user, bool _isAdd, bool _isUni) private {
        if(_isUni){
            manaPoolLib.setLpUniAmount(_user, manaPoolLib.getLpUniAmount(_user).add(_isAdd ? _amountInWei : 0).sub(!_isAdd ? _amountInWei : 0));
        }else{
            manaPoolLib.setLpPancakeAmount(_user, manaPoolLib.getLpPancakeAmount(_user).add(_isAdd ? _amountInWei : 0).sub(!_isAdd ? _amountInWei : 0));
        }
    }
}
