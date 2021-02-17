pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nfts/childChain/ERC721.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nfts/childChain/AccessControlMixin.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nfts/childChain/NativeMetaTransaction.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/nfts/childChain/ContextMixin.sol";

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}

contract ChildERC721 is
    ERC721,
    IChildToken,
    AccessControlMixin,
    NativeMetaTransaction,
    ContextMixin
{
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // limit batching of tokens due to gas limit restrictions
    uint256 public constant BATCH_LIMIT = 20;

    event WithdrawnBatch(
        address indexed user,
        uint256[] tokenIds
    );
    
    address public openSeaOperator;
    //MUMBAI childChainManager 0xb5505a6d998549090530911180f38ac5130101c6
    constructor(
        string memory name_,
        string memory symbol_,
        address childChainManager,
        address _openSeaOperator,
        string memory _baseUrl
    ) public ERC721(name_, symbol_) {
        _setupContractId("ChildERC721");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);
        _initializeEIP712(name_);
        setupOpenSeaOperator(_openSeaOperator);
        setBaseURI(_baseUrl);
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required tokenId for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded tokenId
     */
    function deposit(address user, bytes calldata depositData)
        external
        override
        only(DEPOSITOR_ROLE)
    {
        // deposit single
        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            _mint(user, tokenId);

        // deposit batch
        } else {
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; i++) {
                _mint(user, tokenIds[i]);
            }
        }
    }

    /**
     * @notice called when user wants to withdraw token back to root chain
     * @dev Should burn user's token. This transaction will be verified when exiting on root chain
     * @param tokenId tokenId to withdraw
     */
    function withdraw(uint256 tokenId) external {
        require(_msgSender() == ownerOf(tokenId), "ChildERC721: INVALID_TOKEN_OWNER");
        _burn(tokenId);
    }

    /**
     * @notice called when user wants to withdraw multiple tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param tokenIds tokenId list to withdraw
     */
    function withdrawBatch(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        require(length <= BATCH_LIMIT, "ChildERC721: EXCEEDS_BATCH_LIMIT");
        for (uint256 i; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_msgSender() == ownerOf(tokenId), string(abi.encodePacked("ChildERC721: INVALID_TOKEN_OWNER ", tokenId)));
            _burn(tokenId);
        }
        emit WithdrawnBatch(_msgSender(), tokenIds);
    }
    
    /**
    * As another option for supporting trading without requiring meta transactions, override isApprovedForAll to whitelist OpenSea proxy accounts on Matic
    */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        if (_operator == openSeaOperator) {
            return true;
        }
        
        return ERC721.isApprovedForAll(_owner, _operator);
    }
    
    function setupOpenSeaOperator(address _operator) public only(DEFAULT_ADMIN_ROLE) {
        openSeaOperator = _operator;
    }
    
    function setBaseURI(string memory _baseUrl) public only(DEFAULT_ADMIN_ROLE){
        _setBaseURI(_baseUrl);
    }
    
    function getTokensByOwner(address _owner) public view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);

            for (uint256 index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }

            return result;
        }
    }
}
