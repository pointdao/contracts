// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {LibDiamond} from "./LibDiamond.sol";
import {LibAppStorage, AppStorage} from "./LibAppStorage.sol";
import {LibMeta} from "./LibMeta.sol";
import {IEcliptic} from "../../common/interfaces/IUrbit.sol";

library LibUrbit {
    function updateEcliptic(AppStorage storage s) internal {
        require(address(s.azimuth) != address(0), "Azimuth address not set");
        s.ecliptic = IEcliptic(s.azimuth.owner());
    }

    function setManagementProxy(uint32 _point, address _manager) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.setManagementProxy(_point, _manager);
    }

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.setSpawnProxy(_prefix, _spawnProxy);
    }

    function setVotingProxy(uint8 _galaxy, address _voter) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.setVotingProxy(_galaxy, _voter);
    }

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.castDocumentVote(_galaxy, _proposal, _vote);
    }

    function castUpgradeVote(
        uint8 _galaxy,
        address _proposal,
        bool _vote
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.castUpgradeVote(_galaxy, _proposal, _vote);
    }

    function transferPoint(
        uint32 _point,
        address _target,
        bool _reset
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        updateEcliptic(s);
        s.ecliptic.transferPoint(_point, _target, _reset);
    }
}
