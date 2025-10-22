const hre = require("hardhat");
var frontendUtil = require('@arcologynetwork/frontend-util/utils/util') 

async function main() {
    accounts = await ethers.getSigners(); 

    console.log('======start deploying contract======')
    const ba_factory = await ethers.getContractFactory("BoolArray");
    const ba = await ba_factory.deploy();
    await ba.deployed();
    console.log(`Deployed BoolArray Test at ${ba.address}`)

    console.log('======start executing TXs calling add======')
    var txs=new Array();
    for(i=1;i<=10;i++){
      txs.push(frontendUtil.generateTx(function([ba,from]){
        return ba.connect(from).add();
      },ba,accounts[i]));
    }
    await frontendUtil.waitingTxs(txs);
    
    console.log('======get array length======')
    tx = await ba.length();
    const receipt=await tx.wait();
    frontendUtil.showResult(frontendUtil.parseReceipt(receipt));
    console.log(frontendUtil.parseEvent(receipt,"CounterQuery"))
    if(frontendUtil.parseEvent(receipt,"CounterQuery")==="0x000000000000000000000000000000000000000000000000000000000000000a"){
      console.log('Test Successful');
    }else{
      console.log('Test Failed');
    } 
  }

  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });