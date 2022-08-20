// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// import {AppStorage, Modifiers} from "../../diamond/libraries/LibAppStorage.sol";
import {MockNewAppStorage} from "./MockNewLibAppStorage.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {LibMeta} from "../../diamond/libraries/LibMeta.sol";
import {IEcliptic} from "../../common/interfaces/IUrbit.sol";
import {LibUrbit} from "../../diamond/libraries/LibUrbit.sol";
import {LibPointToken} from "../../diamond/libraries/LibPointToken.sol";

contract MockFacet {
    MockNewAppStorage internal s;

    function modifyNewField(uint256 num) external {
        s.test[num] = !s.test[num];
    }

    function getNewField(uint256 num) external view returns (bool) {
        return s.test[num];
    }

    function modifyTokenName(string calldata _name) external {
        s.tokenName = _name;
    }
}
