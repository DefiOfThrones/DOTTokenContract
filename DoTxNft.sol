pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/AccessControl.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/ERC721Burnable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/ERC721Pausable.sol";

contract DoTxNFT is ERC721, AccessControl, ERC721Burnable, ERC721Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    bytes32 public constant HOUSE_CREATOR_ROLE = keccak256("HOUSE_CREATOR_ROLE");

    mapping(uint256 => uint256) public nextHouseId;
    mapping(uint256 => uint256) public supply;
    

    uint32 public constant ID_TO_HOUSE = 1000000;
    event NewHouse(uint256 id, uint256 maxSupply);

    constructor() public ERC721("DeFi of Thrones NFT", "DoTxNFT"){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setBaseURI("https://nfttest.defiofthrones.io/");
    }
    
    function newModel(uint256 id, uint256 maxSupply) external {
        require(hasRole(HOUSE_CREATOR_ROLE, _msgSender()), "DoTxNFT: require house creator role");
        require(maxSupply <= ID_TO_HOUSE, "DoTxNFT: max supply too high");
        require(supply[id] == 0, "DoTxNFT: house already exist");

        supply[id] = maxSupply;
        NewHouse(id, maxSupply);
    }
    
    function mint(address to, uint256 houseId) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "DoTxNFT: must have minter role to mint");
        
        require(supply[houseId] != 0, "DoTxNFT: house does not exist");
        require(nextHouseId[houseId] < supply[houseId], "DoTxNFT: house sold out");
        uint256 tokenId = houseId * ID_TO_HOUSE + nextHouseId[houseId];
        nextHouseId[houseId]++;

        _mint(to, tokenId);
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "DoTxNFT: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "DoTxNFT: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}