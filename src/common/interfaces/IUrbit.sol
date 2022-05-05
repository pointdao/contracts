// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC173} from "./IERC173.sol";

interface IAzimuth is IERC173 {}

interface IEcliptic is IERC721 {
    function setManagementProxy(uint32 _point, address _manager) external;

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) external;

    function setVotingProxy(uint8 _galaxy, address _voter) external;

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external;

    function castUpgradeVote(
        uint8 _galaxy,
        address _proposal,
        bool _vote
    ) external;

    function createGalaxy(uint8 _galaxy, address _target) external;

    function transferPoint(
        uint32 _point,
        address _target,
        bool _reset
    ) external;
}
