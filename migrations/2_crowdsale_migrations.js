var GDR = artifacts.require("GDR");
var preICO = artifacts.require("PreICO");



module.exports = function(deployer) {


    deployer.deploy(GDR).then(function(){
        return deployer.deploy(preICO, Date.now(), 1,"0x627306090abab3a6e1400e9345bc60c78a8bef57", GDR.address, 12305041990000);
    }).then(function() {
        return GDR.deployed();
    }).then(function (tokenInstance) {
        return tokenInstance.transferOwnership(preICO.address);
    })
};