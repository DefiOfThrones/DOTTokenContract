pragma solidity ^0.6.0;

import "./IERC20.sol";
import "./IERC165.sol";

interface IERC1363 is IERC20, IERC165 {


    function transferAndCall(address to, uint256 value) external returns (bool);

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    function approveAndCall(address spender, uint256 value) external returns (bool);

    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}