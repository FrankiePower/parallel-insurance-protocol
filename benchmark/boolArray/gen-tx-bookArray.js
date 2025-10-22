const hre = require("hardhat");
var frontendUtil = require('@arcologynetwork/frontend-util/utils/util')
const nets = require('../../network.json');
const ProgressBar = require('progress');
async function main() {
  accounts = await ethers.getSigners();
  const provider = new ethers.providers.JsonRpcProvider(nets[hre.network.name].url);
  const pkCreator = nets[hre.network.name].accounts[0]
  const signerCreator = new ethers.Wallet(pkCreator, provider);
  const txbase = 'benchmark/boolArray/txs';
  frontendUtil.ensurePath(txbase);

  let i, tx;

  console.log('======start deploying contract======')
  const boolarray_factory = await ethers.getContractFactory("BoolArray");
  const boolarray = await boolarray_factory.deploy();
  await boolarray.deployed();
  console.log(`Deployed boolarray Test at ${boolarray.address}`)

  console.log('======start generating TXs calling add======')
  let accountsLength = accounts.length
  frontendUtil.ensurePath(txbase + '/add');
  const handle_boolarray = frontendUtil.newFile(txbase + '/add/boolarray.out');

  const bar = new ProgressBar('Generating Tx data [:bar] :percent :etas', {
    total: 100,
    width: 40,
    complete: '*',
    incomplete: ' ',
  });

  const percent = accountsLength / 100
  let pk, signer
  for (i = 0; i < accountsLength; i++) {
    pk = nets[hre.network.name].accounts[i];
    signer = new ethers.Wallet(pk, provider);

    //add
    tx = await boolarray.connect(accounts[i]).populateTransaction.add();
    await frontendUtil.writePreSignedTxFile(handle_boolarray, signer, tx);
    if (i > 0 && i % percent == 0) {
      bar.tick(1);
    }
  }
  bar.tick(1);

  if (bar.complete) {
    console.log(`Test data generation completed: ${accountsLength}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
