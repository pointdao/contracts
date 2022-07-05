pragma solidity 0.4.24;

import {Azimuth} from "./Azimuth.sol";
import {Claims} from "./Claims.sol";
import {Polls} from "./Polls.sol";
import {EclipticBase} from "./EclipticBase.sol";
import {AddressUtils} from "./AddressUtils.sol";
import {ERC721Receiver} from "./ERC721Receiver.sol";
import {SafeMath} from "./SafeMath.sol";
import {SupportsInterfaceWithLookup} from "./SupportsInterfaceWithLookup.sol";
import {ITreasuryProxy} from "./ITreasuryProxy.sol";
import {ERC721Metadata} from "./ERC721Metadata.sol";

contract Ecliptic is EclipticBase, SupportsInterfaceWithLookup, ERC721Metadata {
    using SafeMath for uint256;
    using AddressUtils for address;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes4 constant erc721Received = 0x150b7a02;

    address public constant depositAddress = 0x1111111111111111111111111111111111111111;

    ITreasuryProxy public treasuryProxy;

    bytes32 public constant treasuryUpgradeHash = hex"26f3eae628fa1a4d23e34b91a4d412526a47620ced37c80928906f9fa07c0774";

    bool public treasuryUpgraded = false;

    Claims public claims;

    constructor(
        address _previous,
        Azimuth _azimuth,
        Polls _polls,
        Claims _claims,
        ITreasuryProxy _treasuryProxy
    ) public EclipticBase(_previous, _azimuth, _polls) {
        claims = _claims;
        treasuryProxy = _treasuryProxy;

        _registerInterface(0x80ac58cd); // ERC721
        _registerInterface(0x5b5e139f); // ERC721Metadata
        _registerInterface(0x7f5828d0); // ERC173 (ownership)
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        require(0x0 != _owner);
        return azimuth.getOwnedPointCount(_owner);
    }

    function ownerOf(uint256 _tokenId) public view validPointId(_tokenId) returns (address owner) {
        uint32 id = uint32(_tokenId);

        require(azimuth.isActive(id));

        return azimuth.getOwner(id);
    }

    function exists(uint256 _tokenId) public view returns (bool doesExist) {
        return ((_tokenId < 0x100000000) && azimuth.isActive(uint32(_tokenId)));
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes _data
    ) public {
        transferFrom(_from, _to, _tokenId);
        if (_to.isContract()) {
            bytes4 retval = ERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == erc721Received);
        }
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public validPointId(_tokenId) {
        uint32 id = uint32(_tokenId);
        require(azimuth.isOwner(id, _from));
        transferPoint(id, _to, true);
    }

    function approve(address _approved, uint256 _tokenId) public validPointId(_tokenId) {
        setTransferProxy(uint32(_tokenId), _approved);
    }

    function setApprovalForAll(address _operator, bool _approved) public {
        require(0x0 != _operator);
        azimuth.setOperator(msg.sender, _operator, _approved);
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId) public view validPointId(_tokenId) returns (address approved) {
        require(azimuth.isActive(uint32(_tokenId)));
        return azimuth.getTransferProxy(uint32(_tokenId));
    }

    function isApprovedForAll(address _owner, address _operator) public view returns (bool result) {
        return azimuth.isOperator(_owner, _operator);
    }

    function name() external view returns (string) {
        return "Azimuth Points";
    }

    function symbol() external view returns (string) {
        return "AZP";
    }

    function tokenURI(uint256 _tokenId) public view validPointId(_tokenId) returns (string _tokenURI) {
        _tokenURI = "https://azimuth.network/erc721/0000000000.json";
        bytes memory _tokenURIBytes = bytes(_tokenURI);
        _tokenURIBytes[31] = bytes1(48 + ((_tokenId / 1000000000) % 10));
        _tokenURIBytes[32] = bytes1(48 + ((_tokenId / 100000000) % 10));
        _tokenURIBytes[33] = bytes1(48 + ((_tokenId / 10000000) % 10));
        _tokenURIBytes[34] = bytes1(48 + ((_tokenId / 1000000) % 10));
        _tokenURIBytes[35] = bytes1(48 + ((_tokenId / 100000) % 10));
        _tokenURIBytes[36] = bytes1(48 + ((_tokenId / 10000) % 10));
        _tokenURIBytes[37] = bytes1(48 + ((_tokenId / 1000) % 10));
        _tokenURIBytes[38] = bytes1(48 + ((_tokenId / 100) % 10));
        _tokenURIBytes[39] = bytes1(48 + ((_tokenId / 10) % 10));
        _tokenURIBytes[40] = bytes1(48 + ((_tokenId / 1) % 10));
    }

    function configureKeys(
        uint32 _point,
        bytes32 _encryptionKey,
        bytes32 _authenticationKey,
        uint32 _cryptoSuiteVersion,
        bool _discontinuous
    ) external activePointManager(_point) onL1(_point) {
        if (_discontinuous) {
            azimuth.incrementContinuityNumber(_point);
        }
        azimuth.setKeys(_point, _encryptionKey, _authenticationKey, _cryptoSuiteVersion);
    }

    function spawn(uint32 _point, address _target) external {
        require(azimuth.isOwner(_point, 0x0));

        uint16 prefix = azimuth.getPrefix(_point);

        require(depositAddress != azimuth.getOwner(prefix));
        require(depositAddress != azimuth.getSpawnProxy(prefix));

        require((uint8(azimuth.getPointSize(prefix)) + 1) == uint8(azimuth.getPointSize(_point)));

        require((azimuth.hasBeenLinked(prefix)) && (azimuth.getSpawnCount(prefix) < getSpawnLimit(prefix, block.timestamp)));

        require(azimuth.canSpawnAs(prefix, msg.sender));

        if (msg.sender == _target) {
            doSpawn(_point, _target, true, 0x0);
        } else {
            doSpawn(_point, _target, false, azimuth.getOwner(prefix));
        }
    }

    function doSpawn(
        uint32 _point,
        address _target,
        bool _direct,
        address _holder
    ) internal {
        azimuth.registerSpawned(_point);

        if (_direct) {
            azimuth.activatePoint(_point);
            azimuth.setOwner(_point, _target);

            emit Transfer(0x0, _target, uint256(_point));
        } else {
            azimuth.setOwner(_point, _holder);
            azimuth.setTransferProxy(_point, _target);

            emit Transfer(0x0, _holder, uint256(_point));
            emit Approval(_holder, _target, uint256(_point));
        }
    }

    function transferPoint(
        uint32 _point,
        address _target,
        bool _reset
    ) public {
        require(azimuth.canTransfer(_point, msg.sender));

        require(depositAddress != _target || (azimuth.getPointSize(_point) != Azimuth.Size.Galaxy && !azimuth.getOwner(_point).isContract()));

        if (!azimuth.isActive(_point)) {
            azimuth.activatePoint(_point);
        }

        if (!azimuth.isOwner(_point, _target)) {
            address old = azimuth.getOwner(_point);

            azimuth.setOwner(_point, _target);

            azimuth.setTransferProxy(_point, 0);

            emit Transfer(old, _target, uint256(_point));
        }
        if (depositAddress == _target) {
            azimuth.setKeys(_point, 0, 0, 0);
            azimuth.setManagementProxy(_point, 0);
            azimuth.setVotingProxy(_point, 0);
            azimuth.setTransferProxy(_point, 0);
            azimuth.setSpawnProxy(_point, 0);
            claims.clearClaims(_point);
            azimuth.cancelEscape(_point);
        } else if (_reset) {
            if (azimuth.hasBeenLinked(_point)) {
                azimuth.incrementContinuityNumber(_point);
                azimuth.setKeys(_point, 0, 0, 0);
            }
            azimuth.setManagementProxy(_point, 0);
            azimuth.setVotingProxy(_point, 0);
            azimuth.setTransferProxy(_point, 0);
            if (depositAddress != azimuth.getSpawnProxy(_point)) {
                azimuth.setSpawnProxy(_point, 0);
            }
            claims.clearClaims(_point);
        }
    }

    function escape(uint32 _point, uint32 _sponsor) external activePointManager(_point) onL1(_point) {
        require(depositAddress != azimuth.getOwner(_sponsor));

        require(canEscapeTo(_point, _sponsor));
        azimuth.setEscapeRequest(_point, _sponsor);
    }

    function cancelEscape(uint32 _point) external activePointManager(_point) {
        azimuth.cancelEscape(_point);
    }

    function adopt(uint32 _point) external onL1(_point) {
        uint32 request = azimuth.getEscapeRequest(_point);
        require(azimuth.isEscaping(_point) && azimuth.canManage(request, msg.sender));
        require(depositAddress != azimuth.getOwner(request));

        azimuth.doEscape(_point);
    }

    function reject(uint32 _point) external {
        uint32 request = azimuth.getEscapeRequest(_point);
        require(azimuth.isEscaping(_point) && azimuth.canManage(request, msg.sender));
        require(depositAddress != azimuth.getOwner(request));
        azimuth.cancelEscape(_point);
    }

    function detach(uint32 _point) external {
        uint32 sponsor = azimuth.getSponsor(_point);
        require(azimuth.hasSponsor(_point) && azimuth.canManage(sponsor, msg.sender));
        require(depositAddress != azimuth.getOwner(sponsor));

        azimuth.loseSponsor(_point);
    }

    function getSpawnLimit(uint32 _point, uint256 _time) public view returns (uint32 limit) {
        Azimuth.Size size = azimuth.getPointSize(_point);

        if (size == Azimuth.Size.Galaxy) {
            return 255;
        } else if (size == Azimuth.Size.Star) {
            uint256 yearsSince2019 = (_time - 1546300800) / 365 days;
            if (yearsSince2019 < 6) {
                limit = uint32(1024 * (2**yearsSince2019));
            } else {
                limit = 65535;
            }
            return limit;
        } else {
            return 0;
        }
    }

    function canEscapeTo(uint32 _point, uint32 _sponsor) public view returns (bool canEscape) {
        if (!azimuth.hasBeenLinked(_sponsor)) return false;
        Azimuth.Size pointSize = azimuth.getPointSize(_point);
        Azimuth.Size sponsorSize = azimuth.getPointSize(_sponsor);
        return (((uint8(sponsorSize) + 1) == uint8(pointSize)) || ((sponsorSize == pointSize) && !azimuth.hasBeenLinked(_point)));
    }

    function setManagementProxy(uint32 _point, address _manager) external activePointManager(_point) onL1(_point) {
        azimuth.setManagementProxy(_point, _manager);
    }

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) external activePointSpawner(_prefix) onL1(_prefix) {
        require(depositAddress != azimuth.getSpawnProxy(_prefix));

        azimuth.setSpawnProxy(_prefix, _spawnProxy);
    }

    function setVotingProxy(uint8 _galaxy, address _voter) external activePointVoter(_galaxy) {
        azimuth.setVotingProxy(_galaxy, _voter);
    }

    function setTransferProxy(uint32 _point, address _transferProxy) public onL1(_point) {
        address owner = azimuth.getOwner(_point);
        require((owner == msg.sender) || azimuth.isOperator(owner, msg.sender));
        azimuth.setTransferProxy(_point, _transferProxy);
        emit Approval(owner, _transferProxy, uint256(_point));
    }

    function startUpgradePoll(uint8 _galaxy, EclipticBase _proposal) external activePointVoter(_galaxy) {
        require(_proposal.previousEcliptic() == address(this));
        polls.startUpgradePoll(_proposal);
    }

    function startDocumentPoll(uint8 _galaxy, bytes32 _proposal) external activePointVoter(_galaxy) {
        polls.startDocumentPoll(_proposal);
    }

    function castUpgradeVote(
        uint8 _galaxy,
        EclipticBase _proposal,
        bool _vote
    ) external activePointVoter(_galaxy) {
        bool majority = polls.castUpgradeVote(_galaxy, _proposal, _vote);
        if (majority) {
            upgrade(_proposal);
        }
    }

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external activePointVoter(_galaxy) {
        polls.castDocumentVote(_galaxy, _proposal, _vote);
    }

    function updateUpgradePoll(EclipticBase _proposal) external {
        bool majority = polls.updateUpgradePoll(_proposal);

        if (majority) {
            upgrade(_proposal);
        }
    }

    function updateDocumentPoll(bytes32 _proposal) external {
        polls.updateDocumentPoll(_proposal);
    }

    function upgradeTreasury(address _treasuryImpl) external {
        require(!treasuryUpgraded);
        require(keccak256(_treasuryImpl) == treasuryUpgradeHash);
        treasuryProxy.upgradeTo(_treasuryImpl);
        treasuryUpgraded = true;
    }

    function createGalaxy(uint8 _galaxy, address _target) external onlyOwner {
        require(azimuth.isOwner(_galaxy, 0x0) && 0x0 != _target);

        polls.incrementTotalVoters();

        if (msg.sender == _target) {
            doSpawn(_galaxy, _target, true, 0x0);
        } else {
            doSpawn(_galaxy, _target, false, msg.sender);
        }
    }

    function setDnsDomains(
        string _primary,
        string _secondary,
        string _tertiary
    ) external onlyOwner {
        azimuth.setDnsDomains(_primary, _secondary, _tertiary);
    }

    modifier validPointId(uint256 _id) {
        require(_id < 0x100000000);
        _;
    }
    modifier onL1(uint32 _point) {
        require(depositAddress != azimuth.getOwner(_point));
        _;
    }
}
