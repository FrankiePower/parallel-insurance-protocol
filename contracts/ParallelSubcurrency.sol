// This is a parallel subcurrency example from the Solidity documentation. 
// The original contract can be found here: https://docs.soliditylang.org/en/latest/introduction-to-smart-contracts.html#subcurrency-example

// NO changes were made to the original contract. This is natually a parallel contract.

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;
import "@arcologynetwork/concurrentlib/lib/map/AddressU256Cum.sol";

contract ParallelCoin {
    // The keyword "public" makes variables
    // accessible from other contracts
    address public minter;
    // mapping(address => uint) public balances;
    AddressU256CumMap balances = new AddressU256CumMap();

    event Balance(uint256 bal);

    // Events allow clients to react to specific
    // contract changes you declare
    event Sent(address from, address to, uint amount);
    
    // Constructor code is only run when the contract
    // is created
    constructor() {
        minter = msg.sender;
    }

    // Sends an amount of newly created coins to an address
    // Can only be called by the contract creator
    function mint(address receiver, uint amount) public {
        require(msg.sender == minter);
        // balances[receiver] += amount;
        balances.set(receiver, int256(amount), 0, type(uint256).max);
    }
    
    // Errors allow you to provide information about
    // why an operation failed. They are returned
    // to the caller of the function.
    // error InsufficientBalance(uint requested, uint available);

    // Sends an amount of existing coins
    // from any caller to an address
    function send(address receiver, uint amount) public {
        require(amount <= balances.get(msg.sender),"InsufficientBalance");
        // balances[msg.sender] -= amount;
        // balances[receiver] += amount;
        balances.set(msg.sender, -int256(amount));
        balances.set(receiver, int256(amount), 0, type(uint256).max);
        emit Sent(msg.sender, receiver, amount);
    }
    
    function getter(address sender) public returns(uint256) {
        uint256 bal=balances.get(sender);
        emit Balance(bal);
        return bal;
    }
}