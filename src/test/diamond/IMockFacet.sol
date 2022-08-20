// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IMockFacet {
    function modifyNewField(uint256 num) external;

    function getNewField(uint256 num) external view returns (bool);

    function modifyTokenName(string calldata _name) external;
}
