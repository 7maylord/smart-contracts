// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Assessment
 * @dev A simple contract to manage deposits and withdrawals of Ether.
 * Fixes critical vulnerabilities from the original code.
 */
contract Assessment {
    // Tracks the internal balance (separate from the contract's actual Ether balance)
    uint256 public balance;

    // Events to track deposits and withdrawals
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    // Custom error for gas-efficient reverts
    error InsufficientBalance(uint256 balance, uint256 withdrawAmount);

    /**
     * @dev Deposit Ether into the contract. 
     * Uses `msg.value` to track real Ether sent by the user.
     */
    function deposit() public payable {
        balance += msg.value; // Increase internal balance by the Ether sent
        emit Deposit(msg.value);
    }

    /**
     * @dev Withdraw Ether from the contract.
     * @param _withdrawAmount The amount of Ether to withdraw.
     * - Checks for sufficient internal balance.
     * - Checks for sufficient contract Ether balance.
     * - Transfers Ether to the caller.
     */
    function withdraw(uint256 _withdrawAmount) public {
        // Check internal balance
        if (balance < _withdrawAmount) {
            revert InsufficientBalance({
                balance: balance,
                withdrawAmount: _withdrawAmount
            });
        }

        // Check contract's actual Ether balance
        require(
            address(this).balance >= _withdrawAmount,
            "Contract has insufficient Ether"
        );

        // Update internal balance
        balance -= _withdrawAmount;

        // Transfer Ether to the caller (reverts on failure)
        payable(msg.sender).transfer(_withdrawAmount);

        emit Withdraw(_withdrawAmount);
    }

    /**
     * @dev Returns the contract's actual Ether balance (on-chain).
     * This is separate from the internal `balance` variable.
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}