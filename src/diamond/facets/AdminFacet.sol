// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {IEcliptic} from "../../common/interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract AdminFacet is Modifiers {
    function updateEcliptic() public onlyGovernanceOrOwnerOrMultisigOrManager {
        LibUrbit.updateEcliptic(s);
    }

    function runMigration(address migration, bytes calldata _calldata) external onlyGovernanceOrOwnerOrMultisig {
        bytes4 selector = bytes4(_calldata[:4]);
        LibDiamond.runMigration(migration, selector, _calldata);
    }

    function pauseTokenTransfers() public whenNotPaused onlyGovernanceOrOwnerOrMultisig {
        LibPointToken.pause();
    }

    function unpauseTokenTransfers() public whenPaused onlyGovernanceOrOwnerOrMultisig {
        LibPointToken.unpause();
    }

    function setManager(address manager) public onlyGovernanceOrOwnerOrMultisig {
        s.governance.manager = manager;
    }
}
