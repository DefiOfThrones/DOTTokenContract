pragma solidity ^0.6.0;

interface IERC1363Spender {
    function onApprovalReceived(address owner, uint256 value, bytes calldata data) external returns (bytes4);
}