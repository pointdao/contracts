// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {MockNewAppStorage} from "./MockNewLibAppStorage.sol";

contract MockMigration1Init {
    MockNewAppStorage internal s;

    function init() external {
        s.tokenName = "New facet initialized";
        s.test[0] = true;
    }
}
