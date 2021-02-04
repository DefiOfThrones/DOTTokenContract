pragma solidity ^0.6.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";

interface IDoTxTokenContract{
  function transfer(address recipient, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/**
 * @title MumbaiDoTxGiveawayContract
 * @author DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract MumbaiDoTxGiveawayContract {

  using SafeMath for uint256;
  
  uint256 public feedDoTx = 50000000000000000000000;
  uint256 public feedLp = 500000000000000000000;
  
  mapping (address=>bool) public giveawayDonePerUser;
  IDoTxTokenContract private dotx;
  IDoTxTokenContract private lpToken;


  constructor(address dotxAddress, address lpAddress) public {
    dotx = IDoTxTokenContract(dotxAddress);
    lpToken = IDoTxTokenContract(lpAddress);
  }
    /**
   * Each user can get once time 50k DoTx & 500 LP tokens
   */
    function getTokens() public payable validGiveAway{
        giveawayDonePerUser[msg.sender] = true;
        
        dotx.transfer(msg.sender, feedDoTx);
        lpToken.transfer(msg.sender, feedLp);
    }
    
    modifier validGiveAway() {
        require(giveawayDonePerUser[msg.sender] == false);
        _;
    }
}