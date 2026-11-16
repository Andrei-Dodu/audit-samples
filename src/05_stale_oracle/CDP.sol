// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface AggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice CDP that prices collateral from the feed's answer and never looks at
///         the timestamp or the round completeness. A feed that stops updating, or
///         an L2 sequencer that is down, keeps the last price live forever.
/// @dev FIX: require `updatedAt` within a per-feed heartbeat (HEARTBEAT below is
///      the intended bound and is deliberately unused), require
///      `answeredInRound >= roundId`, and on L2 also check the sequencer uptime
///      feed before pricing.
contract CDP {
    AggregatorV3 public immutable FEED;
    uint256 public constant HEARTBEAT = 1 hours;

    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;

    constructor(AggregatorV3 feed_) {
        FEED = feed_;
    }

    function deposit() external payable {
        collateral[msg.sender] += msg.value;
    }

    /// @notice Borrow up to 50% of the collateral's oracle value. Debt is
    ///         denominated in the feed's unit and paid out 1:1 in wei, which keeps
    ///         the example to one feed.
    function borrow(uint256 amount) external {
        debt[msg.sender] += amount;
        require(debt[msg.sender] * 2 <= collateralValue(msg.sender), "undercollateralised");
        payable(msg.sender).transfer(amount);
    }

    function collateralValue(address who) public view returns (uint256) {
        (, int256 answer,,,) = FEED.latestRoundData();
        return (collateral[who] * uint256(answer)) / 1e18;
    }

    receive() external payable {}
}
