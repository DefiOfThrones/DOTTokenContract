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

interface IDoTxNFT{
  function nftsDbIds(string memory _collection, string memory _dbId) external view returns (uint256);
  function mintDoTx(address _to, string memory _collection, int betProtected, int rewardMalus, uint256 requiredLevel, string memory category, string memory itemType) external;
  function nextDoTxId() external returns(uint256);
}


interface IDoTxNFTUtils{
    struct PENDING_TX {
        address[] addressTo;
        string[] source;
        string[] collection;
    }

    function dequeuePendingTx() external returns (PENDING_TX memory data);
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

contract DoTxNFTMinter is Ownable {
    address public dotxAddress;
    IDoTxTokenContract private dotxToken;
    
    IDoTxNFT private dotxNFT;

    IDoTxNFTUtils private dotxNFTUtils;
    
    uint256[] public indexes;
    
    constructor(address _doTxAddress, address _dotxNFT, address _dotxNFTUtils) public{
        setDoTx(_doTxAddress);
        setDoTxNFT(_dotxNFT);
        setDoTxNFTUtils(_dotxNFTUtils);
    }
    
    /*
    Set DoTx Address & token
    */
    function setDoTx(address _dotx) public onlyOwner {
        dotxAddress = _dotx;
        dotxToken = IDoTxTokenContract(_dotx);
    }
    
    function setDoTxNFT(address _dotxNFT) public onlyOwner {
        dotxNFT = IDoTxNFT(_dotxNFT);
    }

    function setDoTxNFTUtils(address _dotxNFTUtils) public onlyOwner {
        dotxNFTUtils = IDoTxNFTUtils(_dotxNFTUtils);
    }
    
    function mintNftsAndDequeue(address[] memory _receivers, string[] memory _collection, int[] memory _betProtected, int[] memory _rewardMalus, uint256[] memory _requiredXp, string[] memory _category, string[] memory _itemType) public onlyOwner {
        indexes = new uint256[](_receivers.length);
        
        for(uint256 i=0; i < _receivers.length; i++){
            dotxNFT.mintDoTx(_receivers[i], _collection[i], _betProtected[i], _rewardMalus[i], _requiredXp[i], _category[i], _itemType[i]);
            indexes[i] = dotxNFT.nextDoTxId();
        }
        dotxNFTUtils.dequeuePendingTx();
    }

    function mintNFT(address _receiver, string memory _collection, int _betProtected, int _rewardMalus, uint256 _requiredXp, string memory _category, string memory _itemType) public onlyOwner {
        dotxNFT.mintDoTx(_receiver, _collection, _betProtected, _rewardMalus, _requiredXp, _category, _itemType);
    }

    function mintNFTAndDequeue(address _receiver, string memory _collection, int _betProtected, int _rewardMalus, uint256 _requiredXp, string memory _category, string memory _itemType) public onlyOwner {
        dotxNFT.mintDoTx(_receiver, _collection, _betProtected, _rewardMalus, _requiredXp, _category, _itemType);
        dotxNFTUtils.dequeuePendingTx();
    }
    
    function getLastIndexes() public view returns(uint256[] memory){
        return indexes;
    }

    function withdrawDoTx(uint256 _amount) public onlyOwner {
        dotxToken.transfer(owner(), _amount);
    }
}
