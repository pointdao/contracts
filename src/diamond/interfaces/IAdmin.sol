// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IAdmin {
    function updateEcliptic() external;

    function runMigration(address migration, bytes calldata _calldata) external;

    function pauseTokenTransfers() external;

    function unpauseTokenTransfers() external;
}
