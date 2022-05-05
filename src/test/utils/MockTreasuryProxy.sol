// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract MockTreasuryProxy {
    function upgradeTo(address _impl) external pure returns (bool) {
        return true;
    }

    function freeze() external pure returns (bool) {
        return true;
    }
}
