
pragma solidity ^0.6.0;


import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/ERC20Capped.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/ERC20Burnable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/ERC1363.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/Roles.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/TokenRecover.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/libs/Pausable.sol";

/**
 * @title DotTokenContract
 * @author DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract DotTokenContract is ERC20Capped, ERC20Burnable, ERC1363, Roles, TokenRecover, Pausable {

    // indicates if transfer is enabled
    bool private _transferEnabled = false;

    /**
     * Emitted during transfer enabling
     */
    event TransferEnabled();

    /**
     * Tokens can be moved only after if transfer enabled or if you are an approved operator.
     */
    modifier canTransfer(address from) {
        require(
            _transferEnabled || hasRole(OPERATOR_ROLE, from),
            "DotTokenContract: transfer is not enabled or from does not have the OPERATOR role"
        );
        _;
    }
    
    modifier validDestination( address to ) {
        require(to != address(0x0));
        require(to != address(this) );
        _;
    }

    /**
     * @param name Name of the token
     * @param symbol A symbol to be used as ticker
     * @param decimals Number of decimals. All the operations are done using the smallest and indivisible token unit
     * @param cap Maximum number of tokens mintable
     * @param initialSupply Initial token supply
     * @param transferEnabled If transfer is enabled on token creation
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 cap,
        uint256 initialSupply,
        bool transferEnabled
    )
        public
        ERC20Capped(cap)
        ERC1363(name, symbol)
    {
        require(
            cap == initialSupply,
            "DotTokenContract: cap must be equal to initialSupply"
        );

        _setupDecimals(decimals);

        if (initialSupply > 0) {
            _mint(owner(), initialSupply);
        }

        if (transferEnabled) {
            enableTransfer();
        }
    }

    /**
     * @return if transfer is enabled or not.
     */
    function transferEnabled() public view returns (bool) {
        return _transferEnabled;
    }

    /**
     * Transfer tokens to a specified address.
     * @param to The address to transfer to
     * @param value The amount to be transferred
     * @return A boolean that indicates if the operation was successful.
     */
    function transfer(address to, uint256 value) public virtual override(ERC20) validDestination(to) canTransfer(_msgSender()) whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    /**
     * Transfer tokens from one address to another.
     * @param from The address which you want to send tokens from
     * @param to The address which you want to transfer to
     * @param value the amount of tokens to be transferred
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFrom(address from, address to, uint256 value) public virtual override(ERC20) validDestination(to) canTransfer(from) whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }
    
    
    function approve(address spender, uint256 amount) public virtual override(ERC20) whenNotPaused returns (bool) {
         return super.approve(spender, amount);
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public virtual override(ERC20) whenNotPaused returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override(ERC20) whenNotPaused returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }

    /**
     * Function to enable transfers.
     */
    function enableTransfer() public onlyOwner {
        _transferEnabled = true;

        emit TransferEnabled();
    }

    /**
     * See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Capped) validDestination(to) {
        super._beforeTokenTransfer(from, to, amount);
    }
}