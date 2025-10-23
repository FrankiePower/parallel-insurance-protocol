# Arcology Concurrent Programming - Guardrails & Best Practices

## Overview
This document establishes critical guardrails for building parallel contracts on Arcology based on studying the official example contracts and concurrent library implementation.

---

## 🚨 Critical Rules - DO NOT BREAK

### Rule 1: NEVER Mix Concurrent Primitives with Standard Solidity State
```solidity
// ❌ WRONG - Will cause conflicts
uint256 public totalPolicies;  // Standard counter
U256Cumulative public premiumPool;  // Concurrent counter

function createPolicy() public {
    totalPolicies++;  // Sequential write
    premiumPool.add(premium);  // Concurrent write
    // These two will conflict!
}

// ✅ CORRECT - Use concurrent primitives everywhere
U256Cumulative public totalPolicies;
U256Cumulative public premiumPool;

function createPolicy() public {
    totalPolicies.add(1);  // Concurrent
    premiumPool.add(premium);  // Concurrent
    // Both can execute in parallel!
}
```

### Rule 2: U256Cumulative MUST Have Bounds
```solidity
// ❌ WRONG - No constructor call
U256Cumulative public counter;

// ✅ CORRECT - Always initialize with min and max bounds
U256Cumulative public counter = new U256Cumulative(0, type(uint256).max);
```

**Why bounds matter:**
- Arcology uses bounds to validate concurrent operations
- Operations that would exceed bounds will FAIL
- Prevents overflow/underflow in parallel execution

### Rule 3: AddressU256CumMap.set() Requires Bounds on First Write
```solidity
// First write to a NEW key requires bounds
balances.set(receiver, int256(amount), 0, type(uint256).max);

// Subsequent writes to EXISTING key can omit bounds
balances.set(receiver, int256(amount));
```

**Pattern from ParallelSubcurrency.sol:**
```solidity
// Line 34: Initial mint (new key)
balances.set(receiver, int256(amount), 0, type(uint256).max);

// Line 48-49: Subsequent operations (existing keys)
balances.set(msg.sender, -int256(amount));  // Subtract
balances.set(receiver, int256(amount), 0, type(uint256).max);  // Add (might be new)
```

**Safe pattern - Always use bounds:**
```solidity
function transfer(address to, uint256 amount) public {
    // Always safe to include bounds
    balances.set(msg.sender, -int256(amount), 0, type(uint256).max);
    balances.set(to, int256(amount), 0, type(uint256).max);
}
```

### Rule 4: Multiprocess Gas Limits are Per-Job
```solidity
Multiprocess mp = new Multiprocess(5);  // 5 parallel threads

for (uint i = 0; i < 5; i++) {
    mp.addJob(
        2000000,  // ⚠️ This is gas PER JOB, not total
        0,
        address(this),
        abi.encodeWithSignature("processPolicy(uint256)", i)
    );
}

mp.run();  // Total gas: 2M * 5 = 10M gas used
```

### Rule 5: Multiprocess Jobs Must Be Public Functions
```solidity
// ❌ WRONG - Internal/private functions won't work
function _processInternal(uint256 id) internal {
    // Multiprocess can't call this
}

// ✅ CORRECT - Must be public or external
function processPolicy(uint256 id) public {
    // Multiprocess can call this
}
```

### Rule 6: NO Standard Arrays for Parallel Operations
```solidity
// ❌ WRONG - Standard arrays create conflicts
mapping(address => bytes32[]) public userPolicies;

function createPolicy() public {
    userPolicies[msg.sender].push(policyId);  // Write conflict!
}

// ✅ CORRECT - Use concurrent primitives or unique storage
mapping(bytes32 => Policy) public policies;  // Unique keys = no conflict
U256Cumulative public policyCount;  // Concurrent counter

function createPolicy() public {
    bytes32 policyId = keccak256(abi.encodePacked(msg.sender, block.timestamp, policyCount.get()));
    policies[policyId] = Policy(...);  // Unique key
    policyCount.add(1);  // Concurrent increment
}
```

---

## 📚 Available Concurrent Primitives

### Commutative Counters

#### U256Cumulative
- **Purpose**: Thread-safe counter with bounds
- **Operations**: `add()`, `sub()`, `get()`, `min()`, `max()`
- **Use cases**: Total counts, balances, sums

```solidity
import "@arcologynetwork/concurrentlib/lib/commutative/U256Cum.sol";

U256Cumulative totalPolicies = new U256Cumulative(0, type(uint256).max);
totalPolicies.add(1);
uint256 count = totalPolicies.get();
```

### Concurrent Maps

#### AddressU256CumMap
- **Purpose**: Map address → uint256 with cumulative operations
- **Key operations**:
  - `set(address key, int256 delta)` - Add/subtract delta
  - `set(address key, int256 initDelta, uint256 lower, uint256 upper)` - Initialize with bounds
  - `get(address key)` - Read value
  - `exist(address key)` - Check if key exists
- **Use cases**: User balances, per-user counters

```solidity
import "@arcologynetwork/concurrentlib/lib/map/AddressU256Cum.sol";

AddressU256CumMap balances = new AddressU256CumMap();

// First write (new key)
balances.set(user, int256(100), 0, type(uint256).max);

// Subsequent writes
balances.set(user, int256(50));  // Add 50
balances.set(user, -int256(25));  // Subtract 25

uint256 balance = balances.get(user);
```

#### HashU256CumMap
- **Purpose**: Map bytes32 → uint256 (for non-address keys)
- **Same operations as AddressU256CumMap**
- **Use cases**: Token tracking, arbitrary ID mappings

```solidity
import "@arcologynetwork/concurrentlib/lib/map/HashU256Cum.sol";

HashU256CumMap tokenRiskScores = new HashU256CumMap();

bytes32 tokenId = bytes32(uint256(uint160(tokenAddress)));
tokenRiskScores.set(tokenId, int256(100), 0, 10000);
```

### Concurrent Arrays

#### Bool (Concurrent Boolean Array)
- **Purpose**: Thread-safe boolean array
- **Operations**: `push()`, `fullLength()`, `get(index)`
- **Important**: Read operations (`fullLength()`) conflict with writes (`push()`)

```solidity
import "@arcologynetwork/concurrentlib/lib/array/Bool.sol";

Bool flags = new Bool();
flags.push(true);  // Thread-safe parallel pushes
uint256 len = flags.fullLength();  // ⚠️ Don't call this while pushing in parallel
```

### Batch Execution

#### Multiprocess
- **Purpose**: Execute multiple function calls in parallel
- **Constructor**: `new Multiprocess(numThreads)` - 1 to 255 threads
- **Operations**:
  - `addJob(gasLimit, ethValue, contractAddr, encodedCall)` - Queue job
  - `run()` - Execute all jobs in parallel
- **Use cases**: Batch policy creation, mass claim settlement

```solidity
import "@arcologynetwork/concurrentlib/lib/multiprocess/Multiprocess.sol";

Multiprocess mp = new Multiprocess(10);  // 10 parallel threads

for (uint i = 0; i < 100; i++) {
    mp.addJob(
        1500000,  // Gas per job
        0,        // ETH to send
        address(this),
        abi.encodeWithSignature("createPolicyInternal(address,uint256)", users[i], amounts[i])
    );
}

mp.run();  // Execute all 100 jobs across 10 threads in parallel
```

---

## 🎯 Patterns for Rug Insurance Contract

### Pattern 1: Global Counters (Commutative)
```solidity
// All global statistics use U256Cumulative
U256Cumulative public totalPolicies = new U256Cumulative(0, type(uint256).max);
U256Cumulative public totalCoverage = new U256Cumulative(0, type(uint256).max);
U256Cumulative public totalPremiums = new U256Cumulative(0, type(uint256).max);
U256Cumulative public totalClaims = new U256Cumulative(0, type(uint256).max);
U256Cumulative public premiumPool = new U256Cumulative(0, type(uint256).max);

function createPolicy(uint256 coverage, uint256 premium) public {
    totalPolicies.add(1);
    totalCoverage.add(coverage);
    totalPremiums.add(premium);
    premiumPool.add(premium);
}
```

### Pattern 2: Per-User Tracking
```solidity
// Track per-user statistics with AddressU256CumMap
AddressU256CumMap public userPolicyCount = new AddressU256CumMap();
AddressU256CumMap public userTotalCoverage = new AddressU256CumMap();
AddressU256CumMap public userTotalPremiums = new AddressU256CumMap();

function createPolicy(address user, uint256 coverage, uint256 premium) internal {
    // Initialize on first use (or use bounds every time for safety)
    userPolicyCount.set(user, 1, 0, type(uint256).max);
    userTotalCoverage.set(user, int256(coverage), 0, type(uint256).max);
    userTotalPremiums.set(user, int256(premium), 0, type(uint256).max);
}
```

### Pattern 3: Per-Token Tracking
```solidity
// Use HashU256CumMap for token-based data (non-address keys)
HashU256CumMap public tokenRiskScores = new HashU256CumMap();
HashU256CumMap public tokenPolicyCount = new HashU256CumMap();
HashU256CumMap public tokenTotalCoverage = new HashU256CumMap();

function updateTokenStats(address token, uint256 coverage) internal {
    bytes32 tokenId = bytes32(uint256(uint160(token)));

    tokenPolicyCount.set(tokenId, 1, 0, type(uint256).max);
    tokenTotalCoverage.set(tokenId, int256(coverage), 0, type(uint256).max);
}
```

### Pattern 4: Unique Per-Policy Storage (No Conflicts)
```solidity
// Standard mappings are fine if keys are ALWAYS unique
mapping(bytes32 => Policy) public policies;
mapping(bytes32 => ClaimData) public claims;

function createPolicy() public returns (bytes32) {
    // Generate UNIQUE policy ID
    bytes32 policyId = keccak256(
        abi.encodePacked(
            msg.sender,
            block.timestamp,
            block.number,
            totalPolicies.get()  // Ensures uniqueness
        )
    );

    // Store in mapping (no conflict - unique key)
    policies[policyId] = Policy({...});

    return policyId;
}
```

### Pattern 5: Batch Policy Creation with Multiprocess
```solidity
Multiprocess public mp;  // Initialize in constructor or as needed

function batchCreatePolicies(
    address[] calldata tokens,
    uint256[] calldata amounts
) external {
    require(tokens.length == amounts.length, "Length mismatch");

    // Create multiprocess instance with appropriate thread count
    mp = new Multiprocess(tokens.length > 10 ? 10 : tokens.length);

    for (uint i = 0; i < tokens.length; i++) {
        mp.addJob(
            2000000,  // Estimated gas per policy creation
            0,
            address(this),
            abi.encodeWithSignature(
                "createPolicyInternal(address,address,uint256)",
                msg.sender,
                tokens[i],
                amounts[i]
            )
        );
    }

    mp.run();  // Execute all in parallel
}

// Must be public for Multiprocess to call
function createPolicyInternal(
    address user,
    address token,
    uint256 amount
) public {
    // Standard policy creation logic
    // All using concurrent primitives
}
```

### Pattern 6: Batch Claim Settlement
```solidity
function batchSettleClaims(bytes32[] calldata claimIds) external {
    mp = new Multiprocess(claimIds.length > 50 ? 50 : claimIds.length);

    for (uint i = 0; i < claimIds.length; i++) {
        mp.addJob(
            1500000,
            0,
            address(this),
            abi.encodeWithSignature("settleClaimInternal(bytes32)", claimIds[i])
        );
    }

    mp.run();
}

function settleClaimInternal(bytes32 claimId) public {
    // Claim settlement logic
    // Update concurrent maps/counters
}
```

---

## ⚠️ Common Pitfalls & Solutions

### Pitfall 1: Forgetting Bounds on First Write
```solidity
// ❌ Will fail silently or error
AddressU256CumMap balances = new AddressU256CumMap();
balances.set(newUser, int256(100));  // No bounds!

// ✅ Always include bounds for safety
balances.set(newUser, int256(100), 0, type(uint256).max);
```

### Pitfall 2: Using Negative Deltas Without Checking
```solidity
// ❌ Dangerous - might go below 0
balances.set(user, -int256(amount));  // What if balance < amount?

// ✅ Check balance first or handle failure
uint256 currentBalance = balances.get(user);
require(currentBalance >= amount, "Insufficient balance");
balances.set(user, -int256(amount), 0, type(uint256).max);
```

### Pitfall 3: Reading During Concurrent Writes
```solidity
// ❌ Race condition
function transfer() public {
    uint256 balance = balances.get(msg.sender);  // Read
    balances.set(msg.sender, -int256(amount));   // Write
    // Another tx might have modified balance between read and write!
}

// ✅ Use atomic operations
function transfer() public {
    // Direct delta operation is atomic
    balances.set(msg.sender, -int256(amount), 0, type(uint256).max);
    balances.set(receiver, int256(amount), 0, type(uint256).max);
}
```

### Pitfall 4: Multiprocess Gas Underestimation
```solidity
// ❌ Too low gas limit per job
mp.addJob(100000, 0, address(this), data);  // Might fail!

// ✅ Estimate properly or use generous limit
mp.addJob(2000000, 0, address(this), data);  // Safe buffer
```

### Pitfall 5: Mixing Sequential and Parallel State
```solidity
// ❌ CRITICAL ERROR - Will cause issues
uint256 public totalPolicies;  // Sequential
U256Cumulative public totalCoverage;  // Parallel

function create() public {
    totalPolicies++;  // Sequential write
    totalCoverage.add(coverage);  // Parallel write
    // These create a dependency that breaks parallelism!
}

// ✅ Use concurrent for EVERYTHING
U256Cumulative public totalPolicies = new U256Cumulative(0, type(uint256).max);
U256Cumulative public totalCoverage = new U256Cumulative(0, type(uint256).max);
```

---

## 🧪 Testing Patterns

### Testing Concurrent Operations
```javascript
const frontendUtil = require('@arcologynetwork/frontend-util/utils/util');

// Generate concurrent transactions
var txs = new Array();
for (i = 1; i <= 100; i++) {
    txs.push(frontendUtil.generateTx(
        function([contract, from, amount]) {
            return contract.connect(from).createPolicy(amount);
        },
        contract,
        accounts[i],
        100 + i
    ));
}

// Wait for all to complete
await frontendUtil.waitingTxs(txs);

// Verify results
const total = await contract.totalPolicies.get();
expect(total).to.equal(100);
```

### Testing Multiprocess
```javascript
// Single transaction with parallel execution
const tx = await contract.batchCreatePolicies(tokens, amounts);
const receipt = await tx.wait();

// Parse results
frontendUtil.showResult(frontendUtil.parseReceipt(receipt));
console.log(frontendUtil.parseEvent(receipt, "PoliciesCreated"));
```

---

## 📊 Benchmark Script Pattern

### Transaction Generation for Benchmarking
```javascript
const hre = require("hardhat");
const frontendUtil = require('@arcologynetwork/frontend-util/utils/util');
const nets = require('./network.json');
const ProgressBar = require('progress');

async function main() {
    accounts = await ethers.getSigners();
    const provider = new ethers.providers.JsonRpcProvider(nets[hre.network.name].url);
    const txbase = 'benchmark/insurance/txs';
    frontendUtil.ensurePath(txbase);

    // Deploy contract
    const factory = await ethers.getContractFactory("ParallelRugInsurance");
    const contract = await factory.deploy(oracle.address, token.address);
    await contract.deployed();

    // Generate transaction batch
    frontendUtil.ensurePath(txbase + '/createPolicy');
    const handle = frontendUtil.newFile(txbase + '/createPolicy/create.out');

    const bar = new ProgressBar('Generating [:bar] :percent', {
        total: 100,
        width: 40
    });

    for (let i = 0; i < accounts.length; i++) {
        const pk = nets[hre.network.name].accounts[i];
        const signer = new ethers.Wallet(pk, provider);

        const tx = await contract.connect(accounts[i]).populateTransaction.createPolicy(
            testTokens[i % 10],
            ethers.utils.parseEther("1000"),
            30 * 24 * 3600  // 30 days
        );

        await frontendUtil.writePreSignedTxFile(handle, signer, tx);

        if (i % (accounts.length / 100) == 0) {
            bar.tick(1);
        }
    }

    console.log(`Generated ${accounts.length} transactions`);
}
```

---

## 🎓 Key Learnings from Example Contracts

### From ParallelLike.sol
- Simple U256Cumulative usage
- Demonstrates basic concurrent counter
- Clean pattern: `new U256Cumulative(0, type(uint256).max)`

### From ParallelSubcurrency.sol
- AddressU256CumMap for user balances
- First write includes bounds: `set(addr, amount, 0, max)`
- Subsequent writes: `set(addr, delta)` or `set(addr, delta, 0, max)` (safer)
- Negative deltas for subtraction: `set(addr, -int256(amount))`

### From MyMultiProcess.sol
- Multiprocess created with thread count: `new Multiprocess(3)`
- Jobs added in loop
- Gas limit specified per job: `addJob(1000000000, 0, address(this), data)`
- `mp.run()` executes all jobs in parallel
- Target function must be public: `function increment(uint256 cols) public`

### From BoolArray.sol
- Concurrent arrays support parallel pushes
- Reading length while pushing creates conflicts
- Separate read and write phases for best performance

---

## ✅ Checklist for Rug Insurance Implementation

- [ ] All counters use `U256Cumulative`
- [ ] User tracking uses `AddressU256CumMap`
- [ ] Token tracking uses `HashU256CumMap`
- [ ] All map writes include bounds (or use bounds everywhere for safety)
- [ ] NO standard arrays for parallel operations
- [ ] NO sequential state mixed with concurrent state
- [ ] Multiprocess jobs target public functions
- [ ] Multiprocess gas limits are generous per job
- [ ] Policy IDs are always unique (no conflicts)
- [ ] All deltas validated before subtraction
- [ ] Test scripts use `frontendUtil` for concurrent txs
- [ ] Benchmark scripts generate transaction batches
- [ ] No read-during-write race conditions

---

## 🔗 Import Reference

```solidity
// Core concurrent primitives
import "@arcologynetwork/concurrentlib/lib/commutative/U256Cum.sol";
import "@arcologynetwork/concurrentlib/lib/map/AddressU256Cum.sol";
import "@arcologynetwork/concurrentlib/lib/map/HashU256Cum.sol";
import "@arcologynetwork/concurrentlib/lib/multiprocess/Multiprocess.sol";

// Optional: Arrays (use with caution due to read/write conflicts)
import "@arcologynetwork/concurrentlib/lib/array/Bool.sol";
import "@arcologynetwork/concurrentlib/lib/array/U256.sol";
```

---

## 🚀 Ready for Implementation

With these guardrails in place, we can now implement the Parallel Rug Insurance contract with confidence that:
1. We're using concurrent primitives correctly
2. We're avoiding common pitfalls
3. We're following proven patterns from Arcology examples
4. Our code will actually execute in parallel as intended

**Next Step**: Begin Phase 1 implementation following TODO.md with these guardrails as our foundation.
