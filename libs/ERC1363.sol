pragma solidity ^0.6.0;



import "./ERC20.sol";
import "./IERC1363.sol";
import "./ERC165.sol";
import "./IERC1363Receiver.sol";
import "./IERC1363Spender.sol";

contract ERC1363 is ERC20, IERC1363, ERC165 {
    using Address for address;

    bytes4 internal constant _INTERFACE_ID_ERC1363_TRANSFER = 0x4bbee2df;

    bytes4 internal constant _INTERFACE_ID_ERC1363_APPROVE = 0xfb9ec8ce;

    bytes4 private constant _ERC1363_RECEIVED = 0x88a7ca5c;

    bytes4 private constant _ERC1363_APPROVED = 0x7b04a2d0;

    constructor (
        string memory name,
        string memory symbol
    ) public payable ERC20(name, symbol) {
        // register the supported interfaces to conform to ERC1363 via ERC165
        _registerInterface(_INTERFACE_ID_ERC1363_TRANSFER);
        _registerInterface(_INTERFACE_ID_ERC1363_APPROVE);
    }

    function transferAndCall(address to, uint256 value) public override returns (bool) {
        return transferAndCall(to, value, "");
    }

    function transferAndCall(address to, uint256 value, bytes memory data) public override returns (bool) {
        transfer(to, value);
        require(_checkAndCallTransfer(_msgSender(), to, value, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    function transferFromAndCall(address from, address to, uint256 value) public override returns (bool) {
        return transferFromAndCall(from, to, value, "");
    }

    function transferFromAndCall(address from, address to, uint256 value, bytes memory data) public override returns (bool) {
        transferFrom(from, to, value);
        require(_checkAndCallTransfer(from, to, value, data), "ERC1363: _checkAndCallTransfer reverts");
        return true;
    }

    function approveAndCall(address spender, uint256 value) public override returns (bool) {
        return approveAndCall(spender, value, "");
    }

    function approveAndCall(address spender, uint256 value, bytes memory data) public override returns (bool) {
        approve(spender, value);
        require(_checkAndCallApprove(spender, value, data), "ERC1363: _checkAndCallApprove reverts");
        return true;
    }

    function _checkAndCallTransfer(address from, address to, uint256 value, bytes memory data) internal returns (bool) {
        if (!to.isContract()) {
            return false;
        }
        bytes4 retval = IERC1363Receiver(to).onTransferReceived(
            _msgSender(), from, value, data
        );
        return (retval == _ERC1363_RECEIVED);
    }

    function _checkAndCallApprove(address spender, uint256 value, bytes memory data) internal returns (bool) {
        if (!spender.isContract()) {
            return false;
        }
        bytes4 retval = IERC1363Spender(spender).onApprovalReceived(
            _msgSender(), value, data
        );
        return (retval == _ERC1363_APPROVED);
    }
}
