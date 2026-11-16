// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Distributor, IERC20} from "../../src/04_unbounded_loop/Distributor.sol";
import {MockERC20} from "./mocks/Mocks.sol";

/// @notice The loop is fine while the holder set is small and dead once it is
///         not. The test measures both ends of that curve instead of asserting a
///         magic number: gas grows linearly and a realistic block budget runs out.
contract UnboundedLoopTest is Test {
    MockERC20 token;
    Distributor distributor;

    function setUp() public {
        token = new MockERC20("Share", "SHR", 18);
        distributor = new Distributor(IERC20(address(token)));
        token.mint(address(distributor), 1_000_000e18);
    }

    function test_gas_grows_with_holders_and_the_call_dies() public {
        uint256 gasSmall = _seedAndMeasure(50);
        uint256 gasLarge = _seedAndMeasure(400);

        emit log_named_uint("gas at 50 holders", gasSmall);
        emit log_named_uint("gas at 400 holders", gasLarge);
        assertGt(gasLarge, gasSmall * 5, "cost scales with the holder set");

        // A 300k budget gets through 50 holders and not 400.
        distributor = new Distributor(IERC20(address(token)));
        for (uint256 i = 0; i < 400; i++) {
            distributor.addHolder(address(uint160(1000 + i)));
        }
        vm.expectRevert();
        distributor.distribute{gas: 300_000}();
    }

    function _seedAndMeasure(uint256 n) internal returns (uint256 used) {
        distributor = new Distributor(IERC20(address(token)));
        token.mint(address(distributor), n * 1e18);
        for (uint256 i = 0; i < n; i++) {
            distributor.addHolder(address(uint160(1000 + i)));
        }
        uint256 before = gasleft();
        distributor.distribute();
        used = before - gasleft();
    }
}
