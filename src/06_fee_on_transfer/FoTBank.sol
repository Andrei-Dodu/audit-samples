// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Credits the requested amount and ignores what actually arrived. With a
///         fee-on-transfer or deflationary token the ledger is over-credited from
///         the first deposit and the last withdrawal is short.
/// @dev FIX: measure the balance delta around `transferFrom` and credit the delta
///      (or reject FoT tokens explicitly and document it).
contract FoTBank {
    IERC20 public immutable TOKEN;
    mapping(address => uint256) public balance;

    constructor(IERC20 token_) {
        TOKEN = token_;
    }

    function deposit(uint256 amount) external {
        TOKEN.transferFrom(msg.sender, address(this), amount);
        balance[msg.sender] += amount; // trusts the amount, not the delta
    }

    function withdraw(uint256 amount) external {
        balance[msg.sender] -= amount;
        TOKEN.transfer(msg.sender, amount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}
