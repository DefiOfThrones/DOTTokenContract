pragma solidity ^0.6.0;

import "./Ownable.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();
  address private _publicSaleContractAddress;
  address private _swapWallet;

  bool public paused = false;

  constructor() public {}

  /**
   * @dev modifier to allow actions only when the contract IS paused
   */
  modifier whenNotPaused() {
    require(!paused || msg.sender == owner() || msg.sender == _publicSaleContractAddress || msg.sender == _swapWallet);
    _;
  }

  /**
   * @dev modifier to allow actions only when the contract IS NOT paused
   */
  modifier whenPaused {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() public onlyOwner whenNotPaused returns (bool) {
    paused = true;
    emit Pause();
    return true;
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() public onlyOwner whenPaused returns (bool) {
    paused = false;
    emit Unpause();
    return true;
  }

  function publicSaleContractAddress() public view returns (address) {
      return _publicSaleContractAddress;
  }

  function publicSaleContractAddress(address publicSaleAddress) public onlyOwner returns (address) {
      _publicSaleContractAddress = publicSaleAddress;
      return _publicSaleContractAddress;
  }

  function swapWallet() public view returns (address) {
      return _swapWallet;
  }

  function swapWallet(address swapWallet) public onlyOwner returns (address) {
      _swapWallet = swapWallet;
      return _swapWallet;
  }
}