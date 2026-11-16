// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Push-payment dividend distributor: every payout loops the whole holder
///         array. Growth of the holder set is unbounded, so the cost of a
///         distribution is unbounded too and eventually exceeds a block.
/// @dev FIX: pull payments (credit a `claimable` mapping, let holders withdraw),
///      or paginate `distribute(start, count)` and never rely on one call.
contract Distributor {
    IERC20 public immutable TOKEN;
    address[] public holders;
    mapping(address => uint256) public owed;

    constructor(IERC20 token_) {
        TOKEN = token_;
    }

    function addHolder(address holder) external {
        holders.push(holder);
        owed[holder] = 1e18;
    }

    function distribute() external {
        for (uint256 i = 0; i < holders.length; i++) {
            require(TOKEN.transfer(holders[i], owed[holders[i]]), "transfer failed");
        }
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}
