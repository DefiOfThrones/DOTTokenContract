pragma solidity ^0.6.0;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/Pausable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/IDotTokenContract.sol";


contract AirDrop is Pausable {

  using SafeMath for uint256;

  bool public isWhitelistEnabled = true;
  uint256 public airDropValueWei;
  mapping (address=>address) public whitelistedAddresses;
  mapping (address=>bool) public ClaimDonePerUser;
  address[] public whitelistedAddressesList;
  IDotTokenContract private tokenAddress;

  constructor(address dotxAddress, uint256 claimValueWei) public {
    tokenAddress = IDotTokenContract(tokenAddress);
    airDropValueWei = claimValueWei;
  }

    function ClaimAirDrop() public {
        
        if(!canClaim(msg.sender)) return;
        
        ClaimDonePerUser[msg.sender] = true;
        tokenAddress.transfer(msg.sender, (airDropValueWei));
    }
    
    function canClaim(address toCheck) view public returns(bool){
        return (tokenAddress.balanceOf(address(this)) > 0
            && (!isWhitelistEnabled || whitelistedAddresses[toCheck] == toCheck)
            && ClaimDonePerUser[toCheck] == false);
    }

    function enableWhitelistVerification() public onlyOwner {
        isWhitelistEnabled = true;
    }
    
    function disableWhitelistVerification() public onlyOwner {
        isWhitelistEnabled = false;
    }

    function addToWhitelist(address sender) public onlyOwner {
        addAddressToWhitelist(sender);
    }
    
    function addToWhitelist(address[] memory addresses) public onlyOwner {
        for(uint i = 0; i < addresses.length; i++){
            addToWhitelist(addresses[i]);
        }
    }
    
    function addAddressToWhitelist(address sender) private onlyOwner
    {
        require(!isAddressWhitelisted(sender));

        whitelistedAddresses[sender] = sender;
        whitelistedAddressesList.push(sender);
    }
    
    function isAddressWhitelisted(address sender) view public returns(bool) {
        return !isWhitelistEnabled || whitelistedAddresses[sender] == sender;
    }
    
    function withdrawTokens(uint256 amount) public onlyOwner {
        tokenAddress.transfer(owner(), amount);
    }
    
    function getAirDropAmountLeft() view public returns(uint256) {
        return tokenAddress.balanceOf(address(this));
    }
}
