const functions = require('firebase-functions');
const request = require('request');
var EthHelper = require ("./ethHelper.js")
var ABI = require ("./config/dotx.js")
require ("./configHelper.js")
var Web3 = require('web3');

//VARS
var provider = new Web3.providers.HttpProvider(BLOCKCHAIN_PROVIDER);
var web3 = new Web3(provider);
var myContract = new web3.eth.Contract(ABI.getABI(), DOTX_CONTRACT_ADDRESS);


exports.getCurrentPrice = functions.https.onRequest((req, response) => {
    fsym = req.query.fsym;
    tsym = req.query.tsym;
    

    request("https://api.coingecko.com/api/v3/coins/list", { json: true }, (err, res, body) => {
        var found = false;
        body.forEach(coin => {
            if(coin.symbol.toLowerCase() === fsym.toLowerCase()){
                found = true;
                return request("https://api.coingecko.com/api/v3/simple/price?ids="+coin.id+"&vs_currencies="+tsym, { json: true }, (err, res, body) => {
                    if (err) { 
                        console.log(err); 
                        return response.status(500).end();
                    }
                
                    response.send(body[coin.id]);
                    response.status(200).end();
                });
            }
        });
        if(!found){
            response.status(500).end();
        }
    });
});


exports.getDotxCirculationSupply = functions.https.onRequest((req, response) => {
    myContract.methods.balanceOf(MARKETING_CONTRACT_ADDRESS).call().then(function(marketingContratBalance) {
        myContract.methods.balanceOf(TEAM_CONTRACT_ADDRESS).call().then(function(teamContratBalance) {
            var doTxMarketingVested = EthHelper.weiToEth(BigInt(marketingContratBalance).toString())
            var doTxTeamLocked = EthHelper.weiToEth(BigInt(teamContratBalance).toString())
            
            var circulationSupply = MAX_SUPPLY - doTxMarketingVested - doTxTeamLocked;
            
            response.send("{\"DoTxCirculationSupply\" : "+circulationSupply+"}");
            response.status(200).end();
        })
    })
});
