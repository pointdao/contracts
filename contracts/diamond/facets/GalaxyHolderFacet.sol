// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {IEcliptic} from "../interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";

contract GalaxyHolderFacet is Modifiers {
    AppStorage internal s;

    function updateEcliptic() external onlyGovernanceOrOwnerOrMultisigOrManager {
        LibUrbit.updateEcliptic(s);
    }

    function setManagementProxy(uint32 _point, address _manager) external onlyGovernanceOrOwnerOrMultisigOrManager {
        LibUrbit.setManagementProxy(_point, _manager);
    }

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) external onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.setSpawnProxy(_prefix, _spawnProxy);
    }

    function setVotingProxy(uint8 _galaxy, address _voter) external onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.setVotingProxy(_galaxy, _voter);
    }

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external onlyGovernance {
        LibUrbit.castDocumentVote(_galaxy, _proposal, _vote);
    }

    function castUpgradeVote(
        uint8 _galaxy,
        address _proposal,
        bool _vote
    ) external onlyGovernance {
        LibUrbit.castUpgradeVote(_galaxy, _proposal, _vote);
    }

    function transferPoint(
        uint32 _point,
        address _target,
        bool _reset
    ) external onlyGovernanceOrOwner {
        LibUrbit.transferPoint(_point, _target, _reset);
    }
}
