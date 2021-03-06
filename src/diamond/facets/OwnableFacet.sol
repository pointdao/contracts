// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IERC173} from "../../common/interfaces/IERC173.sol";

contract OwnableFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
