pragma solidity 0.4.24;

import {Azimuth} from "./Azimuth.sol";

contract ReadsAzimuth {
    Azimuth public azimuth;

    constructor(Azimuth _azimuth) public {
        azimuth = _azimuth;
    }

    modifier activePointOwner(uint32 _point) {
        require(azimuth.isOwner(_point, msg.sender) && azimuth.isActive(_point));
        _;
    }

    modifier activePointManager(uint32 _point) {
        require(azimuth.canManage(_point, msg.sender) && azimuth.isActive(_point));
        _;
    }

    modifier activePointSpawner(uint32 _point) {
        require(azimuth.canSpawnAs(_point, msg.sender) && azimuth.isActive(_point));
        _;
    }

    modifier activePointVoter(uint32 _point) {
        require(azimuth.canVoteAs(_point, msg.sender) && azimuth.isActive(_point));
        _;
    }
}
