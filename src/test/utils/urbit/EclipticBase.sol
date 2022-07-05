pragma solidity 0.4.24;

import {Azimuth} from "./Azimuth.sol";
import {Ownable} from "./Ownable.sol";
import {Polls} from "./Polls.sol";
import {ReadsAzimuth} from "./ReadsAzimuth.sol";

contract EclipticBase is Ownable, ReadsAzimuth {
    event Upgraded(address to);

    Polls public polls;

    address public previousEcliptic;

    constructor(
        address _previous,
        Azimuth _azimuth,
        Polls _polls
    ) internal ReadsAzimuth(_azimuth) {
        previousEcliptic = _previous;
        polls = _polls;
    }

    function onUpgrade() external {
        require(msg.sender == previousEcliptic && this == azimuth.owner() && this == polls.owner());
    }

    function upgrade(EclipticBase _new) internal {
        azimuth.transferOwnership(_new);
        polls.transferOwnership(_new);

        _new.onUpgrade();

        emit Upgraded(_new);
        selfdestruct(_new);
    }
}
