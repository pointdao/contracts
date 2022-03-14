// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

import "./PointTreasury.sol";

contract Vesting is VestingWallet {
    uint64 constant VESTING_DURATION = 8 * 365 * 24 * 60 * 60; // 8 years

    constructor(PointTreasury _treasury)
        VestingWallet(
            address(_treasury),
            uint64(block.timestamp),
            VESTING_DURATION
        )
    {}
}
