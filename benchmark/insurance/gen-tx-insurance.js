const hre = require("hardhat");
var frontendUtil = require('@arcologynetwork/frontend-util/utils/util')
const nets = require('../../network.json');
const ProgressBar = require('progress');

async function main() {
  accounts = await ethers.getSigners();
  const provider = new ethers.providers.JsonRpcProvider(nets[hre.network.name].url);
  const pkCreator = nets[hre.network.name].accounts[0]
  const signerCreator = new ethers.Wallet(pkCreator, provider);
  const txbase = 'benchmark/insurance/txs';
  frontendUtil.ensurePath(txbase);

  let i, tx;

  console.log('======== DEPLOYING CONTRACTS ========')

  // Deploy ParallelCoin for USDC (payment token)
  const ParallelCoin = await ethers.getContractFactory("ParallelCoin");
  const usdc = await ParallelCoin.deploy("Parallel USDC", "pUSDC", 18);
  await usdc.deployed();
  console.log(`Deployed ParallelCoin USDC at ${usdc.address}`)

  // Deploy MockPyth
  const MockPyth = await ethers.getContractFactory("MockPyth");
  const pyth = await MockPyth.deploy();
  await pyth.deployed();
  console.log(`Deployed MockPyth at ${pyth.address}`)

  // Deploy ParallelCoverageManager
  const Insurance = await ethers.getContractFactory("ParallelCoverageManager");
  const insurance = await Insurance.deploy(pyth.address, usdc.address);
  await insurance.deployed();
  console.log(`Deployed ParallelCoverageManager at ${insurance.address}`)

  // Deploy ParallelCoin for ShitCoin (token being insured)
  const shitcoin = await ParallelCoin.deploy("ShitCoin", "SHIT", 18);
  await shitcoin.deployed();
  console.log(`Deployed ShitCoin at ${shitcoin.address}`)

  console.log('\n======== SETUP ========')

  // Use 100 accounts for massive parallel benchmark
  let accountsLength = Math.min(100, accounts.length);
  console.log(`Using ${accountsLength} accounts for benchmark generation`)
  console.log(`This will generate ${accountsLength} concurrent buyPolicy transactions`)

  // Mint USDC to accounts IN PARALLEL (Arcology supports this!)
  console.log(`Minting USDC to ${accountsLength} accounts in parallel...`)
  let mintPromises = [];
  for (i = 0; i < accountsLength; i++) {
    mintPromises.push(usdc.mint(accounts[i].address, ethers.utils.parseEther("100000")));
  }
  await Promise.all(mintPromises);
  console.log(`✓ Minted USDC to ${accountsLength} accounts in parallel`)

  // Approve insurance for all accounts IN PARALLEL
  console.log(`Approving insurance for ${accountsLength} accounts in parallel...`)
  let approvePromises = [];
  for (i = 0; i < accountsLength; i++) {
    approvePromises.push(
      usdc.connect(accounts[i]).approve(insurance.address, ethers.constants.MaxUint256)
    );
  }
  await Promise.all(approvePromises);
  console.log(`✓ Approved insurance for ${accountsLength} accounts in parallel`)

  // Set up Pyth price
  const priceId = ethers.utils.formatBytes32String("SHIT/USD");
  await (await pyth.setPrice(priceId, 100000000, 1000, -8, Math.floor(Date.now() / 1000))).wait();
  console.log(`✓ Set SHIT/USD price to $1.00`)

  // Register token
  await (await insurance.setTokenSupport(shitcoin.address, true)).wait();
  await (await insurance.setPriceIdSupport(priceId, true)).wait();
  console.log(`✓ Registered token and priceId`)

  console.log('\n======== GENERATING TXs FOR buyPolicy ========')
  frontendUtil.ensurePath(txbase + '/insurance');
  const handle_insurance = frontendUtil.newFile(txbase + '/insurance/insurance.out');

  const bar = new ProgressBar('Generating Txs [:bar] :percent :etas', {
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

    // Generate buyPolicy transaction
    tx = await insurance.connect(accounts[i]).populateTransaction.buyPolicy(
      shitcoin.address,
      ethers.utils.parseEther("1000"),  // 1000 USDC coverage
      30 * 24 * 3600,                   // 30 days
      priceId
    );

    await frontendUtil.writePreSignedTxFile(handle_insurance, signer, tx);

    if (i > 0 && i % percent == 0) {
      bar.tick(1);
    }
  }
  bar.tick(1);

  if (bar.complete) {
    console.log(`\nTest data generation completed: ${accountsLength} transactions`);
    console.log(`\nTo run benchmark:`);
    console.log(`npx arcology.net-tx-sender http://YOUR_IP:8545 benchmark/insurance/txs/insurance/`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
