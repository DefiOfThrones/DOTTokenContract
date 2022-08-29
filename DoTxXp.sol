pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () { }

    function _msgSender() public view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _xpManagerContract;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function xpManagerContract() public view returns (address) {
        return _xpManagerContract;
    }

    function setXpManagerContract(address _address) public onlyOwner{
        _xpManagerContract = _address;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender() || _xpManagerContract == _msgSender(), "Ownable: caller is not the owner");
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

contract DoTxXp is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public xp;
    
    constructor(){

    }

    function addMultipleXp(address[] memory _owner, uint256[] memory _xpToAdd)  public onlyOwner {        
        for(uint256 i=0; i < _owner.length; i++){
            addXp(_owner[i], _xpToAdd[i]);
        }
    }

    function addXp(address _owner, uint256 _xpToAdd)  public onlyOwner {        
        xp[_owner] = xp[_owner].add(_xpToAdd);
    }

    function getXp(address _owner) public view returns(uint256) {
        return xp[_owner];
    }
}
