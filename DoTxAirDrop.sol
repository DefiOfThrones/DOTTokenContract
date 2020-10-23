pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/Pausable.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/master/libs/SafeMath.sol";
import "https://raw.githubusercontent.com/DefiOfThrones/DOTTokenContract/feature/dot-token-v2/IDotTokenContract.sol";


contract DoTxAirDrop is Pausable {

  using SafeMath for uint256;

  bool public isWhitelistEnabled = true;
  uint256 public airDropValueWei;
  mapping (bytes=>bool) public whitelistedAddresses;
  mapping (address=>bool) public claimDonePerUser;
  IDotTokenContract private dotxToken;

  constructor(address dotxAddress, uint256 claimValueWei) public {
    dotxToken = IDotTokenContract(dotxAddress);
    airDropValueWei = claimValueWei;
  }

    function claimAirDrop() public whenNotPaused {
        
        require(canClaim(msg.sender), "You already claimed you drop");
        
        claimDonePerUser[msg.sender] = true;
        dotxToken.transfer(msg.sender, airDropValueWei);
    }
    
    function canClaim(address toCheck) view public returns(bool){
        return (dotxToken.balanceOf(address(this)) > 0
            && isAddressWhitelisted(toCheck)
            && claimDonePerUser[toCheck] == false);
    }

    function enableWhitelistVerification(bool enable) public onlyOwner {
        isWhitelistEnabled = enable;
    }

    function setAirDropValueWei(uint256 valueInWei) public onlyOwner {
        airDropValueWei = valueInWei;
    }

    function addToWhitelist(bytes memory sender) public onlyOwner {
        whitelistedAddresses[sender] = true;
    }
    
    function addToWhitelist(bytes[] memory addresses) public onlyOwner {
        for(uint i = 0; i < addresses.length; i++){
            addToWhitelist(addresses[i]);
        }
    }

    
    function withdrawTokens(uint256 amount) public onlyOwner {
        dotxToken.transfer(owner(), amount);
    }
    
    function getAirDropAmountLeft() view public returns(uint256) {
        return dotxToken.balanceOf(address(this));
    }
    
    
   function isAddressWhitelisted(address addr) public view returns(bool) {
        bytes memory addressBytes = addressToBytes(addr);
        bytes memory addressSliced = sliceAddress(addressBytes);
        
        return !isWhitelistEnabled || whitelistedAddresses[addressSliced] == true;
    }
    
    function sliceAddress(bytes memory addrBytes) public pure returns(bytes memory) {
        return abi.encodePacked(addrBytes[0], addrBytes[1], addrBytes[7], addrBytes[19]);
    }
    
    
    function addressToBytes(address a) public pure returns (bytes memory) {
        return abi.encodePacked(a);
    }
    
    function getBalanceFromToken(address tokenAddress, address wallet) public view returns(uint256) {
        IDotTokenContract token = IDotTokenContract(tokenAddress);
        return token.balanceOf(wallet);
    }
}
