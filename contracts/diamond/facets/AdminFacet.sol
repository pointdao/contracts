// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {IEcliptic} from "../interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract AdminFacet is Modifiers {
    AppStorage internal s;

    function runMigration(address migration, bytes memory _calldata) external onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.runMigration(migration, _calldata);
    }

    function pauseTokenTransfers() public whenNotPaused onlyGovernanceOrOwnerOrMultisig {
        LibPointToken.pause();
    }

    function unpauseTokenTransfers() public whenPaused onlyGovernanceOrOwnerOrMultisig {
        LibPointToken.unpause();
    }
}
