// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Payout, IERC20} from "../../src/03_unchecked_transfer/Payout.sol";
import {MockERC20} from "./mocks/Mocks.sol";

/// @notice A token that returns false instead of reverting, the way a paused or
///         blacklisting token behaves. The payout marks the invoice settled
///         anyway, so the operator has to notice it by hand.
contract FalseReturnToken is MockERC20 {
    bool public failing = true;

    constructor() MockERC20("False", "FLS", 18) {}

    function setFailing(bool v) external {
        failing = v;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (failing) return false;
        return super.transfer(to, amount);
    }
}

contract UncheckedTransferTest is Test {
    FalseReturnToken token;
    Payout payout;

    address recipient = makeAddr("recipient");

    function setUp() public {
        token = new FalseReturnToken();
        payout = new Payout(IERC20(address(token)));
        token.mint(address(payout), 1_000e18);
    }

    function test_failed_transfer_is_recorded_as_paid() public {
        bytes32 invoice = keccak256("INV-1");

        payout.pay(invoice, recipient, 1_000e18);

        // No revert, invoice burnt, recipient paid nothing, funds still in the contract.
        assertTrue(payout.settled(invoice), "invoice marked settled");
        assertEq(token.balanceOf(recipient), 0, "recipient received nothing");
        assertEq(token.balanceOf(address(payout)), 1_000e18, "funds never left");
    }
}
