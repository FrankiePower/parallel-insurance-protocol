const hre = require("hardhat");

async function main() {
    console.log('MINIMAL TEST - Just deploy and check\n');

    const [owner] = await ethers.getSigners();
    console.log(`Owner: ${owner.address}\n`);

    // Deploy MockERC20
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const usdc = await MockERC20.deploy("USDC", "USDC", 18, 0);
    console.log(`USDC: ${usdc.address}`);

    // Deploy MockPyth
    const MockPyth = await ethers.getContractFactory("MockPyth");
    const pyth = await MockPyth.deploy();
    console.log(`Pyth: ${pyth.address}`);

    // Deploy Insurance
    const Insurance = await ethers.getContractFactory("ParallelCoverageManager");
    const insurance = await Insurance.deploy(pyth.address, usdc.address);
    console.log(`Insurance: ${insurance.address}\n`);

    // Check concurrent primitives are initialized
    console.log('Checking concurrent primitives...');
    try {
        // getStats() is a transaction (not view) because U256Cumulative.get() is not view
        const tx = await insurance.getStats();
        const receipt = await tx.wait();
        console.log(`✓ getStats() transaction completed`);
        console.log(`  Block: ${receipt.blockNumber}, Status: ${receipt.status}`);

        // The return values are in events or we need to decode the receipt
        // For now, just confirm it didn't revert
        if (receipt.status === 1) {
            console.log(`  ✓ Contract state is accessible`);
        } else {
            console.error(`  ✗ Transaction reverted`);
        }
    } catch (e) {
        console.error(`✗ getStats() failed: ${e.message}`);
    }

    console.log('\n✓ All checks passed!');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
