const hre = require("hardhat");
var frontendUtil = require('@arcologynetwork/frontend-util/utils/util')
const nets = require('../../network.json');
const ProgressBar = require('progress');

async function main() {
  accounts = await ethers.getSigners();
  const provider = new ethers.providers.JsonRpcProvider(nets[hre.network.name].url);
  const pkCreator = nets[hre.network.name].accounts[0]
  const signerCreator = new ethers.Wallet(pkCreator, provider);
  const txbase = 'benchmark/parallelSubCurrency/txs'
  frontendUtil.ensurePath(txbase);

  let i, tx;

  console.log('======start deploying contract======')
  const coin_factory = await ethers.getContractFactory("ParallelCoin");
  const coin = await coin_factory.deploy();
  await coin.deployed();
  console.log(`Deployed parallelSubCurrency Test at ${coin.address}`)

  console.log('======start generating TXs calling mint======')
  let accountsLength = accounts.length
  const bar = new ProgressBar('Generating Tx data [:bar] :percent :etas', {
    total: 100,
    width: 40,
    complete: '*',
    incomplete: ' ',
  });

  const percent = accountsLength / 100
  frontendUtil.ensurePath(txbase + '/mint');
  const handle_mint = frontendUtil.newFile(txbase + '/mint/mint.out');

  etas = 0;
  for (i = 0; i < accountsLength; i++) {
    tx = await coin.populateTransaction.mint(accounts[i].address, 100);
    await frontendUtil.writePreSignedTxFile(handle_mint, signerCreator, tx);
    if (i > 0 && i % percent == 0) {
      bar.tick(1);
    }
    etas = accountsLength - i;
  }
  bar.tick(1);
  if (bar.complete) {
    console.log(`tx data generation completed: ${accountsLength}`);
  }

  console.log('======start generating TXs calling send======')
  frontendUtil.ensurePath(txbase + '/send');
  const handle_send = frontendUtil.newFile(txbase + '/send/send.out');

  const sendCount = accountsLength / 2;
  const bar1 = new ProgressBar('Generating Tx data [:bar] :percent :etas', {
    total: 100,
    width: 40,
    complete: '*',
    incomplete: ' ',
  });

  const percent1 = sendCount / 100
  let pk, signer
  for (i = 0; i < sendCount; i++) {
    pk = nets[hre.network.name].accounts[i];
    signer = new ethers.Wallet(pk, provider);

    tx = await coin.connect(accounts[i]).populateTransaction.mint(accounts[i + sendCount].address, 100);
    await frontendUtil.writePreSignedTxFile(handle_send, signer, tx);
    if (i > 0 && i % percent1 == 0) {
      bar1.tick(1);
    }
  }
  bar1.tick(1);
  if (bar1.complete) {
    console.log(`tx data generation completed: ${sendCount}`);
  }
}

async function writePreSignedTxFile(txfile, signer, tx) {
  const fulltx = await signer.populateTransaction(tx)
  const rawtx = await signer.signTransaction(fulltx)
  frontendUtil.appendTo(txfile, rawtx + ',\n')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
