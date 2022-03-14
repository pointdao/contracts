// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./Point.sol";
import "./urbit/IUrbit.sol";

contract GalaxyLocker is ERC721Holder, Ownable {
    Point public pointToken;
    IOwnable public azimuth;
    address public ecliptic;
    uint256 constant POINT_PER_GALAXY = 1000 * 10**18;

    event Received(address sender, uint256 amount, uint256 balance);

    receive() external payable {
        emit Received(msg.sender, msg.value, address(this).balance);
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

    function setManagementProxy(uint8 _point, address _manager)
        external
        onlyOwner
    {
        _updateEcliptic();
        IEcliptic(ecliptic).setManagementProxy(uint32(_point), _manager);
    }

    function setSpawnProxy(uint8 _point, address _spawnProxy)
        external
        onlyOwner
    {
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
            IERC721(ecliptic).safeTransferFrom(
                address(this),
                _msgSender(),
                uint256(i)
            );
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
}
