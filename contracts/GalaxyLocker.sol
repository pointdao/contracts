// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

import {Point} from "./Point.sol";
import {IEcliptic, IOwnable} from "./urbit/IUrbit.sol";

contract GalaxyLocker is IERC721Receiver, Ownable {
    Point public pointToken;
    IOwnable public azimuth;
    address public ecliptic;
    uint256 constant POINT_PER_GALAXY = 1000 * 10**18;
    uint256 constant MAX_GALAXY_ID = 255;
    mapping(uint8 => bool) private hasGalaxy;

    event Received(address sender, uint256 amount, uint256 balance);
    event GalaxyReceived(address operator, address from, uint8 tokenId);

    receive() external payable {
        emit Received(_msgSender(), msg.value, address(this).balance);
    }

    constructor(
        Point _pointToken,
        address _azimuth,
        address treasury
    ) {
        pointToken = _pointToken;
        azimuth = IOwnable(_azimuth);
        _updateEcliptic();
        transferOwnership(treasury);
    }

    function _updateEcliptic() internal {
        ecliptic = azimuth.owner();
    }

    function setManagementProxy(uint8 _point, address _manager) external onlyOwner {
        _updateEcliptic();
        IEcliptic(ecliptic).setManagementProxy(uint32(_point), _manager);
    }

    function setSpawnProxy(uint8 _point, address _spawnProxy) external onlyOwner {
        _updateEcliptic();
        IEcliptic(ecliptic).setSpawnProxy(uint16(_point), _spawnProxy);
    }

    function setVotingProxy(uint8 _point, address _voter) external onlyOwner {
        _updateEcliptic();
        IEcliptic(ecliptic).setVotingProxy(_point, _voter);
    }

    function takeGalaxies(uint8[] calldata _points) external onlyOwner {
        _updateEcliptic();
        for (uint8 i = 0; i < _points.length; i++) {
            pointToken.burn(_msgSender(), POINT_PER_GALAXY);
            IERC721(ecliptic).safeTransferFrom(address(this), _msgSender(), uint256(i));
        }
    }

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external onlyOwner {
        _updateEcliptic();
        IEcliptic(ecliptic).castDocumentVote(_galaxy, _proposal, _vote);
    }

    function castUpgradeVote(
        uint8 _galaxy,
        address _proposal,
        bool _vote
    ) external onlyOwner {
        _updateEcliptic();
        IEcliptic(ecliptic).castUpgradeVote(_galaxy, _proposal, _vote);
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        _updateEcliptic();
        if (_msgSender() == ecliptic && tokenId <= MAX_GALAXY_ID) {
            if (tokenId <= MAX_GALAXY_ID) {}
        }
        return this.onERC721Received.selector;
    }
}
