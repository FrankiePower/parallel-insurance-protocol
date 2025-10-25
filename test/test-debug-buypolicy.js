const hre = require("hardhat");

async function main() {
    console.log('DEBUG: Testing buyPolicy validation\n');

    const [owner, buyer] = await ethers.getSigners();
    console.log(`Owner: ${owner.address}`);
    console.log(`Buyer: ${buyer.address}\n`);

    // Deploy contracts
    const ParallelCoin = await ethers.getContractFactory("ParallelCoin");
    const usdc = await ParallelCoin.deploy("Parallel USDC", "pUSDC", 18);
    await usdc.deployed();
    console.log(`USDC: ${usdc.address}`);

    const MockPyth = await ethers.getContractFactory("MockPyth");
    const pyth = await MockPyth.deploy();
    await pyth.deployed();
    console.log(`Pyth: ${pyth.address}`);

    const Insurance = await ethers.getContractFactory("ParallelCoverageManager");
    const insurance = await Insurance.deploy(pyth.address, usdc.address);
    await insurance.deployed();
    console.log(`Insurance: ${insurance.address}`);

    const shitcoin = await ParallelCoin.deploy("ShitCoin", "SHIT", 18);
    await shitcoin.deployed();
    console.log(`ShitCoin: ${shitcoin.address}\n`);

    // Setup
    const priceId = ethers.utils.formatBytes32String("SHIT/USD");

    console.log('Step 1: Mint USDC to buyer...');
    await (await usdc.mint(buyer.address, ethers.utils.parseEther("10000"))).wait();
    console.log(`✓ Minted\n`);

    console.log('Step 2: Buyer approves insurance...');
    await (await usdc.connect(buyer).approve(insurance.address, ethers.constants.MaxUint256)).wait();
    console.log(`✓ Approved\n`);

    console.log('Step 3: Set price...');
    await (await pyth.setPrice(
        priceId,
        100000000,
        1000,
        -8,
        Math.floor(Date.now() / 1000)
    )).wait();
    console.log(`✓ Price set\n`);

    console.log('Step 4: Register token support...');
    const tx1 = await insurance.setTokenSupport(shitcoin.address, true);
    const receipt1 = await tx1.wait();
    console.log(`✓ Token support set - Block: ${receipt1.blockNumber}, Status: ${receipt1.status}`);

    console.log('Step 5: Register priceId support...');
    const tx2 = await insurance.setPriceIdSupport(priceId, true);
    const receipt2 = await tx2.wait();
    console.log(`✓ PriceId support set - Block: ${receipt2.blockNumber}, Status: ${receipt2.status}\n`);

    // Verify registration
    console.log('Verifying registration...');
    const isTokenSupported = await insurance.supportedTokens(shitcoin.address);
    console.log(`  supportedTokens[${shitcoin.address}] = ${isTokenSupported}`);

    const isPriceIdSupported = await insurance.supportedPriceIds(priceId);
    console.log(`  supportedPriceIds[${priceId}] = ${isPriceIdSupported}\n`);

    // Try to buy policy
    console.log('Step 6: Attempting buyPolicy...');
    try {
        const tx = await insurance.connect(buyer).buyPolicy(
            shitcoin.address,
            ethers.utils.parseEther("1000"),
            30 * 24 * 3600,
            priceId
        );
        console.log(`  Transaction hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`✓✓✓ SUCCESS! Block: ${receipt.blockNumber}, Status: ${receipt.status}`);
    } catch (error) {
        console.error(`\n❌ FAILED: ${error.message}`);
        if (error.reason) {
            console.error(`Reason: ${error.reason}`);
        }
        if (error.receipt) {
            console.error(`Status: ${error.receipt.status}`);
            console.error(`Gas used: ${error.receipt.gasUsed.toString()}`);
        }
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
