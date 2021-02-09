pragma solidity ^0.6.0;

import "./ERC721PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DoTxNFT is ERC721PresetMinterPauser, Ownable {
    bytes32 public constant MODEL_CREATOR_ROLE =
        keccak256("MODEL_CREATOR_ROLE");

    mapping(uint256 => uint256) public nextId;
    mapping(uint256 => uint256) public supply;

    uint32 public constant ID_TO_MODEL = 1000000;
    event NewModel(uint256 id, uint256 maxSupply);

    constructor()
        public
        ERC721PresetMinterPauser(
            "DeFi of Thrones NFT",
            "DoTxNFT",
            "https://nfttest.defiofthrones.io/"
        )
    {}

    function newModel(uint256 id, uint256 maxSupply) external {
        require(
            hasRole(MODEL_CREATOR_ROLE, _msgSender()),
            "DoTxNFT: require model creator role"
        );
        require(maxSupply <= ID_TO_MODEL, "DoTxNFT: max supply too high");
        require(supply[id] == 0, "DoTxNFT: model already exist");

        supply[id] = maxSupply;
        NewModel(id, maxSupply);
    }

    function mint(address to, uint256 model) public override {
        require(supply[model] != 0, "DoTxNFT: does not exist");
        require(nextId[model] < supply[model], "DoTxNFT: sold out");
        uint256 tokenId = model * ID_TO_MODEL + nextId[model];
        nextId[model]++;
        super.mint(to, tokenId);
    }
}