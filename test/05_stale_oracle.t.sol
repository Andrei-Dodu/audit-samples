// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CDP, AggregatorV3} from "../../src/05_stale_oracle/CDP.sol";

contract MockFeed is AggregatorV3 {
    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId;

    function set(int256 answer_, uint256 updatedAt_) external {
        answer = answer_;
        updatedAt = updatedAt_;
        roundId += 1;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}

/// @notice The feed froze three days ago at $4,000 while the market is at $1,500.
///         Nothing in the contract notices, so the borrower mints against the old
///         price and walks away from a position that is already underwater.
contract StaleOracleTest is Test {
    MockFeed feed;
    CDP cdp;

    address borrower = makeAddr("borrower");

    function setUp() public {
        feed = new MockFeed();
        cdp = new CDP(AggregatorV3(address(feed)));

        vm.deal(borrower, 10 ether);
        vm.deal(address(cdp), 100_000 ether);

        vm.warp(1_800_000_000);
        feed.set(4_000e18, block.timestamp - 3 days); // frozen three days ago
    }

    function test_borrow_against_a_three_day_old_price() public {
        vm.startPrank(borrower);
        cdp.deposit{value: 10 ether}();
        cdp.borrow(19_000e18); // 10 ETH at $4,000 supports 20,000; at $1,500 it supports 7,500
        vm.stopPrank();

        uint256 trueValue = (10 ether * 1_500e18) / 1e18;
        emit log_named_uint("debt", cdp.debt(borrower));
        emit log_named_uint("value at the real price", trueValue);

        assertGt(cdp.debt(borrower), trueValue, "debt exceeds the collateral value at the real price");
        assertEq(feed.updatedAt(), block.timestamp - 3 days, "feed is stale and nobody checked");
    }
}
