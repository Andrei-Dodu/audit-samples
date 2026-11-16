// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Batch payout that marks each invoice settled after `transfer`.
///         The return value is ignored, which is fine for tokens that revert on
///         failure and silently wrong for tokens that return false (USDT-style
///         implementations, paused tokens, blacklisted recipients).
/// @dev FIX: `require(token.transfer(to, amount))`, or use SafeERC20 which
///      reverts on a false return and on a missing return value.
contract Payout {
    IERC20 public immutable TOKEN;
    mapping(bytes32 => bool) public settled;

    constructor(IERC20 token_) {
        TOKEN = token_;
    }

    function pay(bytes32 invoice, address to, uint256 amount) external {
        require(!settled[invoice], "settled");
        settled[invoice] = true;
        TOKEN.transfer(to, amount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
}
