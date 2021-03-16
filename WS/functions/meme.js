const functions = require('firebase-functions');
require ("./configHelper.js")

const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

exports.addLike = functions.https.onRequest((req, response) => {
    addLike = req.query.addLike;
    memeId = req.query.memeId;
    walletId = req.query.walletId.toLowerCase();
    clientIp = req.ip
    db.collection("memes").doc(memeId).get().then((doc) => {
        if (doc.exists) {
            if((addLike == "1" && !doc.data().ips.includes(clientIp) && !doc.data().wallets.includes(walletId))
            ||(addLike == "0" && doc.data().ips.includes(clientIp) && doc.data().wallets.includes(walletId))){
                
                wallets = doc.data().wallets;
                ips = doc.data().ips;

                if(addLike == "1"){
                    currentLikes = doc.data().likes + 1; 
                    wallets.push(walletId)
                    ips.push(clientIp)
                }else{
                    currentLikes = doc.data().likes - 1; 
                    remove(wallets, walletId)
                    remove(ips, clientIp)
                }
                db.collection("memes").doc(memeId).update({likes: currentLikes,
                    wallets : wallets, ips : ips}, { merge: true });
                
                response.set('Access-Control-Allow-Origin', '*');
                response.send('{response : 1}');
                response.status(200).end();
            }else{
                response.set('Access-Control-Allow-Origin', '*');
                response.send('{response : 0, error : "Wallet or ip exists"}');
                response.status(200).end();
            }
        }else{
            response.set('Access-Control-Allow-Origin', '*');
            response.status(404).end();
        }
    })
});

function remove(arr, data){
    const index = arr.indexOf(data);
    
    if (index > -1) {
        return arr.splice(index, 1);
    }
}
