
interface IDotTokenContract{
  function mint(address to, uint256 value) external;
  function balanceOf(address account) external view returns (uint256);
}