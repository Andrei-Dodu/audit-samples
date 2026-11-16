// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal vault: shares mint 1:1 against assets and round down on both
///         legs. Share price comes from the live balance, so anything sent to the
///         contract outside `deposit` moves the price. No virtual offset, no
///         dead-shares lock.
/// @dev FIX: ERC4626 with a virtual share/asset offset (OZ >= 4.9) or a
///      dead-shares seed at first deposit, and round the price in favour of the
///      vault on both legs.
contract Vault {
    IERC20 public immutable ASSET;
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    constructor(IERC20 asset_) {
        ASSET = asset_;
    }

    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this));
    }

    function deposit(uint256 amount) external returns (uint256 minted) {
        uint256 assetsBefore = totalAssets();
        minted = totalShares == 0 ? amount : (amount * totalShares) / assetsBefore;
        ASSET.transferFrom(msg.sender, address(this), amount);
        shares[msg.sender] += minted;
        totalShares += minted;
    }

    function withdraw(uint256 shareAmount) external returns (uint256 paid) {
        paid = (shareAmount * totalAssets()) / totalShares;
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        ASSET.transfer(msg.sender, paid);
    }
}

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}
