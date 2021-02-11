pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/ERC721Burnable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/ERC721Pausable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nft/Ownable.sol";

contract DoTxNFT is ERC721, ERC721Burnable, ERC721Pausable, Ownable {

    mapping(uint256 => uint256) public nextHouseId;
    mapping(uint256 => uint256) public supply;
    

    uint32 public constant ID_TO_HOUSE = 1000000;
    event NewHouse(uint256 id, uint256 maxSupply);

    constructor(string memory _baseUrl) public ERC721("DeFi of Thrones NFT", "DoTxNFT"){//"DeFi of Thrones", "DoTx_NFT"
        setBaseURI(_baseUrl);//"https://nfttest.defiofthrones.io/"
    }
    
    function newHouse(uint256 _houseId, uint256 _maxSupply) external onlyOwner {
        require(_maxSupply <= ID_TO_HOUSE, "DoTxNFT: max supply too high");
        require(supply[_houseId] == 0, "DoTxNFT: house already exist");

        supply[_houseId] = _maxSupply;
        NewHouse(_houseId, _maxSupply);
    }
    
    function mintBatch(address _to, uint256 _houseId, uint256 _count) public onlyOwner {
        require(supply[_houseId] != 0, "DoTxNFT: house does not exist");
        
        for(uint256 i=0; i < _count; i++){
            mint(_to, _houseId);
        }
    }
    
    function mint(address _to, uint256 _houseId) private onlyOwner {
        require(nextHouseId[_houseId] < supply[_houseId], "DoTxNFT: house sold out");
        
        nextHouseId[_houseId]++;
        uint256 tokenId = _houseId * ID_TO_HOUSE + nextHouseId[_houseId];
        
        _mint(_to, tokenId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function setBaseURI(string memory _baseUrl) public onlyOwner{
        _setBaseURI(_baseUrl);
    }
}