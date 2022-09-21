pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

interface IDoTxTokenContract {
  function balanceOf(address account) external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
}

interface IDoTxNFT {
    struct Token {
        string collection;
        uint256 tokenId;
        int betProtected;
        int rewardMalus;
        uint256 requiredXp;
        string category;
        string itemType;
    }

    function nftsDbIds(string memory _collection, string memory _dbId) external view returns (uint256);
    function mintDoTx(address _to, string memory _collection, int betProtected, int rewardMalus, uint256 requiredLevel, string memory category, string memory itemType) external;
    function nextDoTxId() external returns(uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function getTokenInfo(uint256 _tokenId) external view returns(IDoTxNFT.Token memory); 
}

interface IDoTxEquipmentExternal {
    function equipMultiple(address _owner, uint256[] memory _items, string[] memory _itemTypes) external;
    function unEquipMultiple(address _owner, string[] memory _itemTypes) external;
    function equip(address _owner, uint256 _tokenId, string memory _itemType) external;
    function unEquip(address _owner, string memory _itemType) external;
    function getEquipment(address _owner, string memory _itemType) external view returns(uint256);
}

interface IDoTxXp {
    function getXp(address _owner) external view returns(uint256);
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

contract DoTxEquipment is Ownable {
    address public dotxAddress;
    IDoTxTokenContract private dotxToken;
    IDoTxNFT private dotxNFT;
    IDoTxEquipmentExternal private equipmentExternal;
    IDoTxXp private dotxXp;

    struct EQUIPMENT {
        uint256 head;
        uint256 chest;
        uint256 arms;
        uint256 legs;
        uint256 feet;
        uint256 weapon;
        uint256 shield;
    }

    
    constructor(address _doTxAddress, address _dotxNFT, address _equipmentExternal, address _dotxXp) public {
        setDoTx(_doTxAddress);
        setDoTxNFT(_dotxNFT);
        setDoTxEquipmentExternal(_equipmentExternal);
        setDoTxXp(_dotxXp);
    }

    function equipMultiple(uint256[] memory _items) public {        
        for(uint256 i=0; i < _items.length; i++){
            equip(_items[i]);
        }
    }

    function unEquipMultiple(uint256[] memory _items) public {        
        for(uint256 i=0; i < _items.length; i++){
            unEquip(_items[i]);
        }
    }

    function changeEquipment(uint256[] memory _itemsToUnequip, uint256[] memory _itemsToEquip) public {
        unEquipMultiple(_itemsToUnequip);
        equipMultiple(_itemsToEquip);
    }

    function equip(uint256 _tokenId) public returns(IDoTxNFT.Token memory) {
        //dotxNFT.transferFrom(msg.sender, address(this), _tokenId);

        string memory itemType = dotxNFT.getTokenInfo(_tokenId).itemType;
        string memory category = dotxNFT.getTokenInfo(_tokenId).category;
        uint256 requiredXp = dotxNFT.getTokenInfo(_tokenId).requiredXp;

        require(getEquipmentItem(msg.sender, itemType) == 0, "Item already equipped");
        require(dotxXp.getXp(msg.sender) >= requiredXp, "Not enough xp to equip item");
        

        if(compareStrings(itemType, "head") || compareStrings(itemType, "chest") || compareStrings(itemType, "arms")
        || compareStrings(itemType, "legs") || compareStrings(itemType, "feet") || compareStrings(itemType, "weapon")){
            //Equip only 1 time
            
            if(compareStrings(itemType, "weapon")){
                if(compareStrings(category, "2h piercing") || compareStrings(category, "2h striking")){
                    //Can be equiped only if no shield
                    require(getEquipmentItem(msg.sender, "shield") == 0, "Shield already equipped");
                }
            }
        } else if(compareStrings(itemType, "shield")) {
            //Can be equiped only if one hand or nothing
            
            string memory equippedCategory = dotxNFT.getTokenInfo(getEquipmentItem(msg.sender, "weapon")).category;

            require(getEquipmentItem(msg.sender, "weapon") == 0 
            || compareStrings(equippedCategory, "1h piercing") || compareStrings(equippedCategory, "1h striking")
            , "Item cannot be equipped");
        }

        equipmentExternal.equip(msg.sender, _tokenId, itemType);
    }

    function unEquip(uint256 _tokenId) public {
        string memory itemType = dotxNFT.getTokenInfo(_tokenId).itemType;

        require(getEquipmentItem(msg.sender, itemType) != 0, "Item not equipped");

        equipmentExternal.unEquip(msg.sender, itemType);

        //dotxNFT.transferFrom(address(this), msg.sender, _tokenId);
    }

    function getEquipment(address _wallet) public view returns(EQUIPMENT memory) {
        return EQUIPMENT(equipmentExternal.getEquipment(_wallet, "head"),
        equipmentExternal.getEquipment(_wallet, "chest"),
        equipmentExternal.getEquipment(_wallet, "arms"),
        equipmentExternal.getEquipment(_wallet, "legs"),
        equipmentExternal.getEquipment(_wallet, "feet"),
        equipmentExternal.getEquipment(_wallet, "weapon"),
        equipmentExternal.getEquipment(_wallet, "shield"));
    }

    function getEquipmentItem(address _wallet, string memory _itemType) public view returns(uint256) {
        return equipmentExternal.getEquipment(_wallet, _itemType);
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

    function setDoTxEquipmentExternal(address _dotxEquipmentExternal) public onlyOwner {
        equipmentExternal = IDoTxEquipmentExternal(_dotxEquipmentExternal);
    }

    function setDoTxXp(address _dotxXp) public onlyOwner {
        dotxXp = IDoTxXp(_dotxXp);
    }
    
    function withdrawDoTx(uint256 _amount) public onlyOwner {
        dotxToken.transfer(owner(), _amount);
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
