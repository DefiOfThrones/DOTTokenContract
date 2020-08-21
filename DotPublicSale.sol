pragma solidity ^0.6.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/Pausable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/IDotTokenContract.sol";

/**
 * @title PublicSaleContract
 * @author DefiOfThrones (https://github.com/DefiOfThrones/DOTTokenContract)
 */
contract DotPublicSale is Pausable {

  using SafeMath for uint256;

  uint256 public tokenPurchased;
  uint256 public contributors;


  uint256 public constant BASE_PRICE_IN_WEI = 105882000000000;

  bool public isWhitelistEnabled = true;
  uint256 public minWeiPurchasable = 500000000000000000;
  uint256 public maxWeiPurchasable = 3000000000000000000;
  mapping (address=>address) public whitelistedAddresses;
  mapping (address=>bool) public salesDonePerUser;
  address[] public whitelistedAddressesList;
  IDotTokenContract private token;

  uint256 public tokenCap;
  bool public started = true;


  constructor(address tokenAddress, uint256 cap) public {
    token = IDotTokenContract(tokenAddress);
    tokenCap = cap;
  }

  /**
   * High level token purchase function
   */
  receive() external payable {
    buyTokens();
  }

    /**
   * Low level token purchase function
   */
    function buyTokens() public payable validPurchase{
        salesDonePerUser[msg.sender] = true;
        
        uint256 tokenCount = msg.value/BASE_PRICE_IN_WEI;

        tokenPurchased = tokenPurchased.add(tokenCount);
        
        require(tokenPurchased < tokenCap);
    
        contributors = contributors.add(1);
    
        forwardFunds();
        TESTER
        token.transfer(msg.sender, (tokenCount * 10**18));
    }
    
    modifier validPurchase() {
        require(started);
        require(msg.value >= minWeiPurchasable);
        require(msg.value <= maxWeiPurchasable);
        require(!isWhitelistEnabled || whitelistedAddresses[msg.sender] == msg.sender);
        require(salesDonePerUser[msg.sender] == false);
        _;
    }

  /**
  * Forwards funds to the tokensale wallet
  */
  function forwardFunds() internal {
    address payable owner = payable(address(owner()));
    owner.transfer(msg.value);
  }

    function isContract(address _addr) view internal returns(bool) {
        uint size;
        /*if (_addr == 0)
          return false;*/
        assembly {
            size := extcodesize(_addr)
        }
        return size>0;
    }

    function enableWhitelistVerification() public onlyOwner {
        isWhitelistEnabled = true;
    }
    
    function disableWhitelistVerification() public onlyOwner {
        isWhitelistEnabled = false;
    }
    
    function changeMinWeiPurchasable(uint256 value) public onlyOwner {
        minWeiPurchasable = value;
    }
    
    function changeMaxWeiPurchasable(uint256 value) public onlyOwner {
        maxWeiPurchasable = value;
    }
    
    function changeStartedState(bool value) public onlyOwner {
        started = value;
    }

    function addToWhitelist(address sender) public onlyOwner {
        addAddressToWhitelist(sender);
    }
    
    function addAddressToWhitelist(address sender) private onlyOwner
    {
        require(!isAddressWhitelisted(sender));

        whitelistedAddresses[sender] = sender;
        whitelistedAddressesList.push(sender);
    }
    
    function addToWhitelist(address[] memory addresses) public onlyOwner {
        for(uint i = 0; i < addresses.length; i++){
            addToWhitelist(addresses[i]);
        }
    }
    
    function isAddressWhitelisted(address sender) view public returns(bool) {
        return !isWhitelistEnabled || whitelistedAddresses[sender] == sender;
    }
    
    function withdrawTokens(uint256 amount) public onlyOwner {
        token.transfer(owner(), amount);
    }
}
