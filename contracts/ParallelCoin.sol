// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;
import "@arcologynetwork/concurrentlib/lib/map/AddressU256Cum.sol";

/**
 * @title ParallelCoin
 * @dev Parallel ERC20-like token using Arcology concurrent primitives
 * Based on ParallelSubcurrency from Arcology examples
 */
contract ParallelCoin {
    address public minter;
    AddressU256CumMap balances = new AddressU256CumMap();

    // For ERC20 compatibility
    string public name;
    string public symbol;
    uint8 public decimals;

    // Allowances - using nested mapping with AddressU256CumMap
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Mint(address indexed to, uint256 amount);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        minter = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    // Mint tokens (only minter)
    function mint(address receiver, uint256 amount) public {
        require(msg.sender == minter, "Only minter can mint");
        balances.set(receiver, int256(amount), 0, type(uint256).max);
        emit Mint(receiver, amount);
        emit Transfer(address(0), receiver, amount);
    }

    // Get balance
    function balanceOf(address account) public returns (uint256) {
        return balances.get(account);
    }

    // Approve spender
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Transfer tokens
    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    // Transfer from (used by contracts)
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        // Check allowance if not self
        if (from != msg.sender) {
            require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        return _transfer(from, to, amount);
    }

    // Internal transfer using parallel primitives
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(to != address(0), "Transfer to zero address");
        uint256 fromBalance = balances.get(from);
        require(fromBalance >= amount, "Insufficient balance");

        // ✅ PARALLEL-SAFE: Using AddressU256CumMap delta operations
        balances.set(from, -int256(amount));
        balances.set(to, int256(amount), 0, type(uint256).max);

        emit Transfer(from, to, amount);
        return true;
    }
}
