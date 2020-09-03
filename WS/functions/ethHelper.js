var Web3 = require('web3');

class EthHelper {
    
    static weiToEth(amountInWei) {
        return Web3.utils.fromWei(amountInWei, 'ether')
    }
}

module.exports = EthHelper;


