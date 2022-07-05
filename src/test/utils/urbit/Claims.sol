pragma solidity 0.4.24;

import {Azimuth} from "./Azimuth.sol";
import {ReadsAzimuth} from "./ReadsAzimuth.sol";

contract Claims is ReadsAzimuth {
    event ClaimAdded(uint32 indexed by, string _protocol, string _claim, bytes _dossier);
    event ClaimRemoved(uint32 indexed by, string _protocol, string _claim);
    uint8 constant maxClaims = 16;
    struct Claim {
        string protocol;
        string claim;
        bytes dossier;
    }

    mapping(uint32 => Claim[maxClaims]) public claims;

    constructor(Azimuth _azimuth) public ReadsAzimuth(_azimuth) {}

    function addClaim(
        uint32 _point,
        string _protocol,
        string _claim,
        bytes _dossier
    ) external activePointManager(_point) {
        require((0 < bytes(_protocol).length) && (0 < bytes(_claim).length));
        uint8 cur = findClaim(_point, _protocol, _claim);
        if (cur == 0) {
            uint8 empty = findEmptySlot(_point);
            claims[_point][empty] = Claim(_protocol, _claim, _dossier);
        } else {
            claims[_point][cur - 1] = Claim(_protocol, _claim, _dossier);
        }
        emit ClaimAdded(_point, _protocol, _claim, _dossier);
    }

    function removeClaim(
        uint32 _point,
        string _protocol,
        string _claim
    ) external activePointManager(_point) {
        uint256 i = findClaim(_point, _protocol, _claim);

        require(i > 0);
        i--;

        delete claims[_point][i];

        emit ClaimRemoved(_point, _protocol, _claim);
    }

    function clearClaims(uint32 _point) external {
        require(azimuth.canManage(_point, msg.sender) || (msg.sender == azimuth.owner()));

        Claim[maxClaims] storage currClaims = claims[_point];

        for (uint8 i = 0; i < maxClaims; i++) {
            if (0 < bytes(currClaims[i].claim).length) {
                emit ClaimRemoved(_point, currClaims[i].protocol, currClaims[i].claim);
            }

            delete currClaims[i];
        }
    }

    function findClaim(
        uint32 _whose,
        string _protocol,
        string _claim
    ) public view returns (uint8 index) {
        bytes32 protocolHash = keccak256(bytes(_protocol));
        bytes32 claimHash = keccak256(bytes(_claim));
        Claim[maxClaims] storage theirClaims = claims[_whose];
        for (uint8 i = 0; i < maxClaims; i++) {
            Claim storage thisClaim = theirClaims[i];
            if ((protocolHash == keccak256(bytes(thisClaim.protocol))) && (claimHash == keccak256(bytes(thisClaim.claim)))) {
                return i + 1;
            }
        }
        return 0;
    }

    function findEmptySlot(uint32 _whose) internal view returns (uint8 index) {
        Claim[maxClaims] storage theirClaims = claims[_whose];
        for (uint8 i = 0; i < maxClaims; i++) {
            Claim storage thisClaim = theirClaims[i];
            if ((0 == bytes(thisClaim.claim).length)) {
                return i;
            }
        }
        revert();
    }
}
