pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

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
    address private _equiperContract;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function equiperContract() public view returns (address) {
        return _equiperContract;
    }

    function setEquiperContract(address _address) public onlyOwner{
        _equiperContract = _address;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender() || _equiperContract == _msgSender(), "Ownable: caller is not the owner");
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

contract DoTxEquipmentExtern is Ownable {
    
    mapping(address => mapping(string => uint256)) public equipment;     
    
    constructor(){

    }

    function equipMultiple(address _owner, uint256[] memory _items, string[] memory _itemTypes)  public onlyOwner {        
        for(uint256 i=0; i < _items.length; i++){
            equip(_owner, _items[i], _itemTypes[i]);
        }
    }

    function unEquipMultiple(address _owner, string[] memory _itemTypes) public onlyOwner {        
        for(uint256 i=0; i < _itemTypes.length; i++){
            unEquip(_owner, _itemTypes[i]);
        }
    }

    function equip(address _owner, uint256 _tokenId, string memory _itemType) public onlyOwner {
        equipment[_owner][_itemType] = _tokenId;
    }

    function unEquip(address _owner, string memory _itemType) public onlyOwner {
        equipment[_owner][_itemType] = 0;//Unequip
    }

    function getEquipment(address _owner, string memory _itemType) public view returns(uint256) {
        return equipment[_owner][_itemType];
    }
}
