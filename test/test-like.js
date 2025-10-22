const hre = require("hardhat");
var frontendUtil = require('@arcologynetwork/frontend-util/utils/util');
const { expect } = require("chai");

async function main() {
    accounts = await ethers.getSigners(); 

    console.log('======start deploying contract======')
    const bt_factory = await ethers.getContractFactory("Like");
    const bt = await bt_factory.deploy();
    await bt.deployed();
    console.log(`Deployed Like Test at ${bt.address}`)

    console.log('======start executing TXs calling like======')
    var txs=new Array();
    for(i=1;i<=10;i++){
      txs.push(frontendUtil.generateTx(function([bt,from]){
        return bt.connect(from).like();
      },bt,accounts[i]));
    }
    await frontendUtil.waitingTxs(txs);
    expect(await bt.getTotal()).to.equal(10);

  }

  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });