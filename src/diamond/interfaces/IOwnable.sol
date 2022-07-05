// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOwnable {
    function transferOwnership(address _newOwner) external;

    function owner() external view returns (address owner_);
}
