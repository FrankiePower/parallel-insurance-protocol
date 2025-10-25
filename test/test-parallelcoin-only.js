const hre = require("hardhat");

async function main() {
    console.log('TESTING PARALLELCOIN TRANSFERFROM\n');

    const [owner, user1, user2] = await ethers.getSigners();
    console.log(`Owner: ${owner.address}`);
    console.log(`User1: ${user1.address}`);
    console.log(`User2: ${user2.address}\n`);

    // Deploy ParallelCoin
    const ParallelCoin = await ethers.getContractFactory("ParallelCoin");
    const token = await ParallelCoin.deploy("Test Token", "TEST", 18);
    await token.deployed();
    console.log(`ParallelCoin deployed: ${token.address}\n`);

    // Mint 1000 tokens to user1
    console.log('Step 1: Mint 1000 tokens to user1...');
    const mintTx = await token.mint(user1.address, ethers.utils.parseEther("1000"));
    const mintReceipt = await mintTx.wait();
    console.log(`✓ Minted - Block: ${mintReceipt.blockNumber}, Status: ${mintReceipt.status}\n`);

    // User1 approves owner for 500 tokens
    console.log('Step 2: User1 approves owner for 500 tokens...');
    const approveTx = await token.connect(user1).approve(owner.address, ethers.utils.parseEther("500"));
    const approveReceipt = await approveTx.wait();
    console.log(`✓ Approved - Block: ${approveReceipt.blockNumber}, Status: ${approveReceipt.status}\n`);

    // Owner calls transferFrom to move 100 tokens from user1 to user2
    console.log('Step 3: Owner transfers 100 tokens from user1 to user2 using transferFrom...');
    try {
        const transferTx = await token.transferFrom(
            user1.address,
            user2.address,
            ethers.utils.parseEther("100")
        );
        console.log(`  Transaction hash: ${transferTx.hash}`);
        const transferReceipt = await transferTx.wait();
        console.log(`✓ Transferred - Block: ${transferReceipt.blockNumber}, Status: ${transferReceipt.status}\n`);

        console.log('✓✓✓ SUCCESS! ParallelCoin transferFrom works! ✓✓✓');
    } catch (error) {
        console.error(`\n❌ FAILED: ${error.message}`);
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
