const functions = require('firebase-functions');
const request = require('request');
var EthHelper = require ("./ethHelper.js")
var ABI = require ("./config/dotx.js")
require ("./configHelper.js")
var Web3 = require('web3');

const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

//VARS
var provider = new Web3.providers.HttpProvider(BLOCKCHAIN_PROVIDER);
var web3 = new Web3(provider);
var myContract = new web3.eth.Contract(ABI.getABI(), DOTX_CONTRACT_ADDRESS);

/*
exports.getCurrentPrice = functions.https.onRequest((req, response) => {
    fsym = req.query.fsym.toLowerCase();
    tsym = req.query.tsym.toLowerCase();
    fsymId = req.query.fsymId ? req.query.fsymId.toLowerCase() : "";
    

    request("https://api.coingecko.com/api/v3/coins/list", { json: true }, (err, res, body) => {
        var found = false;
        body.forEach(coin => {
            if(coin.symbol.toLowerCase() === fsym && (fsymId == "" || (fsymId == coin.id.toLowerCase()))){
                found = true;
                return request("https://api.coingecko.com/api/v3/simple/price?ids="+coin.id+"&vs_currencies="+tsym, { json: true }, (err, res, body) => {
                    if (err) { 
                        console.log(err); 
                        return response.status(500).end();
                    }
                    response.set('Access-Control-Allow-Origin', '*');
                    response.send(body[coin.id]);
                    response.status(200).end();
                });
            }
        });
        if(!found){
            response.status(500).end();
        }
    });
});*/

exports.getWhitelist = functions.https.onRequest((req, response) => {
    db.collection('whitelist').get()
    .then(snapshot => {
        snapshot.forEach(doc => {
            console.log(doc.id, '=>', doc.data());
            response.send(doc.id);
        });
        response.status(200).end();
    })
    .catch(err => {
        console.log('Error getting documents', err);
        response.send('Error getting documents' + err);
        response.status(200).end();
    });    
});

/*
exports.getDotxCirculationSupply = functions.https.onRequest((req, response) => {
    myContract.methods.balanceOf(MARKETING_CONTRACT_ADDRESS).call().then(function(marketingContratBalance) {
        myContract.methods.balanceOf(TEAM_CONTRACT_ADDRESS).call().then(function(teamContratBalance) {
            myContract.methods.balanceOf(VITALIK_ADDRESS).call().then(function(vitalikBalance) {
                var doTxMarketingVested = EthHelper.weiToEth(BigInt(marketingContratBalance).toString())
                var doTxTeamLocked = EthHelper.weiToEth(BigInt(teamContratBalance).toString())
                var vitalikBurn = EthHelper.weiToEth(BigInt(vitalikBalance).toString())
                
                var circulationSupply = MAX_SUPPLY - doTxMarketingVested - doTxTeamLocked - vitalikBurn;
                
                response.send("{\"DoTxCirculationSupply\" : "+parseInt(circulationSupply, 10)+"}");
                response.status(200).end();
            })
        })
    })
});*/