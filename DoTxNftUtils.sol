pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

interface IDoTxTokenContract{
  function balanceOf(address account) external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
}


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
    address private _owner2;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function owner2() public view returns (address) {
        return _owner2;
    }

    function setOwner2(address _address) public onlyOwner{
        _owner2 = _address;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender() || _owner2 == _msgSender(), "Ownable: caller is not the owner");
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

contract DoTxNFTUtils is Ownable {
    using SafeMath for uint256;
     
    address public dotxAddress;
    IDoTxTokenContract private dotxToken;
    uint256 public bnbFees;

    //PENDING BUY
    mapping(uint256 => PENDING_TX) pendingTx;
    uint256 public firstPending = 1;
    uint256 public lastPending = 0;
    uint256 public counter;
    
    event CreateNFT(address sender, string source, string collection);
    
    struct PENDING_TX {
        address addressTo;
        string source;
        string collection;
    }


    constructor(address _dotxNFT, address _dotx) {
        setDoTx(_dotx);
        
        bnbFees = 100000000000000000;
    }
    
    /*
    Trigger nft creation
    */
    function triggerCreateNFT(string memory _source, string memory _collection) public payable {

        require(msg.value >= bnbFees, "Send the required amount");

        payable(owner()).transfer(msg.value);
                
        enqueuePendingTx(PENDING_TX(msg.sender, _source, _collection));
        
        emit CreateNFT(msg.sender, _source, _collection);
        
        counter++;
    }
    
    
    function setBNBFees(uint256 _fees) public onlyOwner {
        bnbFees = _fees;
    }
    
    /*
    Set revo Address & token
    */
    function setDoTx(address _dotx) public onlyOwner {
        dotxAddress = _dotx;
        dotxToken = IDoTxTokenContract(dotxAddress);
    }

    function withdrawRevo(address user, uint256 _amount) public onlyOwner {
        dotxToken.transfer(user, _amount);
    }
    
    /*
    PENDING BUY QUEUE
    */
    
    function enqueuePendingTx(PENDING_TX memory data) private {
        lastPending += 1;
        pendingTx[lastPending] = data;
    }

    function dequeuePendingTx() public onlyOwner returns (PENDING_TX memory data) {
        require(lastPending >= firstPending);  // non-empty queue

        data = pendingTx[firstPending];

        delete pendingTx[firstPending];
        firstPending += 1;
    }
    
    function countPendingTx() public view returns(uint256){
        return firstPending <= lastPending ? (lastPending - firstPending) + 1 : 0;
    }
    
    function getPendingTx(uint256 _maxItems) public view returns(PENDING_TX[] memory items){
        uint256 count = countPendingTx();
        count = count > _maxItems ? _maxItems : count;
        PENDING_TX[] memory itemToReturn = new PENDING_TX[](count);
        
        for(uint256 i = 0; i < count; i ++){
            itemToReturn[i] =  pendingTx[firstPending + i];
        }
        
        return itemToReturn;
    }
    
    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
