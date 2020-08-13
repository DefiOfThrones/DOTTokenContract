
pragma solidity ^0.6.0;

interface IDotTokenContract{
  function mint(address to, uint256 value) external;
  function balanceOf(address account) external view returns (uint256);
  function totalSupply() external view returns (uint256);
}