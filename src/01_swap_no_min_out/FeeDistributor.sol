// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @notice Converts the fee token it holds into ETH for the treasury, called on a
///         schedule by a keeper. Runs unbounded: no minimum out, no caller-supplied
///         deadline.
/// @dev FIX: compute amountOutMin from a manipulation-resistant reference (TWAP
///      with enough observations, or a signed quote) and revert or skip the swap
///      when the quote is unavailable. Take the deadline from the caller. Never
///      pass block.timestamp.
contract FeeDistributor {
    IRouter public immutable ROUTER;
    address public immutable TOKEN;
    address public immutable TREASURY;
    address[] public path;

    constructor(IRouter router_, address token_, address treasury_, address[] memory path_) {
        ROUTER = router_;
        TOKEN = token_;
        TREASURY = treasury_;
        path = path_;
        IERC20(token_).approve(address(router_), type(uint256).max);
    }

    function distribute() external {
        uint256 balance = IERC20(TOKEN).balanceOf(address(this));
        if (balance == 0) return;

        // amountOutMin = 0, deadline = now: any price is accepted, forever.
        ROUTER.swapExactTokensForTokens(balance, 0, path, TREASURY, block.timestamp);
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}
