// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {FoTBank, IERC20} from "../../src/06_fee_on_transfer/FoTBank.sol";
import {MockERC20} from "./mocks/Mocks.sol";

/// @notice Token that skims 1% on every transfer, the way reflection and
///         burn-on-transfer tokens do.
contract FeeToken is MockERC20 {
    uint256 public constant FEE_BPS = 100;

    constructor() MockERC20("Fee", "FEE", 18) {}

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * FEE_BPS) / 10_000;
        return super.transfer(to, amount - fee);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * FEE_BPS) / 10_000;
        super.transferFrom(from, address(this), fee);
        super.transferFrom(from, to, amount - fee);
        return true;
    }
}

/// @notice Two depositors put in 1,000 each. The ledger says 2,000, the bank holds
///         1,980. The first one out is paid in full, the second is 20 short.
contract FeeOnTransferTest is Test {
    FeeToken token;
    FoTBank bank;

    address first = makeAddr("first");
    address second = makeAddr("second");

    function setUp() public {
        token = new FeeToken();
        bank = new FoTBank(IERC20(address(token)));

        token.mint(first, 1_000e18);
        token.mint(second, 1_000e18);
    }

    function test_ledger_over_credits_and_both_depositors_lose_the_fee() public {
        vm.startPrank(first);
        token.approve(address(bank), type(uint256).max);
        bank.deposit(1_000e18);
        vm.stopPrank();

        vm.startPrank(second);
        token.approve(address(bank), type(uint256).max);
        bank.deposit(1_000e18);
        vm.stopPrank();

        assertEq(bank.balance(first), 1_000e18, "ledger credits the full amount");
        assertEq(token.balanceOf(address(bank)), 1_980e18, "the bank holds 2% less");

        vm.prank(first);
        bank.withdraw(1_000e18);
        vm.prank(second);
        bank.withdraw(1_000e18);

        // Both ledgers are zero, so nothing looks wrong. Each one actually got 990.
        assertEq(bank.balance(first), 0, "ledger cleared");
        assertEq(bank.balance(second), 0, "ledger cleared");
        assertEq(token.balanceOf(first), 990e18, "first lost the fee on the way in and out");
        assertEq(token.balanceOf(second), 990e18, "second lost the same");
        assertEq(token.balanceOf(address(bank)), 0, "bank ends empty");
        emit log_named_uint("first got", token.balanceOf(first));
        emit log_named_uint("second got", token.balanceOf(second));
    }
}
