pragma solidity 0.4.24;

import {Ownable} from "./UrbitOwnable.sol";
import {SafeMath} from "./SafeMath.sol";
import {SafeMath16} from "./SafeMath16.sol";
import {SafeMath8} from "./SafeMath8.sol";

contract Polls is Ownable {
    using SafeMath for uint256;
    using SafeMath16 for uint16;
    using SafeMath8 for uint8;

    event UpgradePollStarted(address proposal);

    event DocumentPollStarted(bytes32 proposal);

    event UpgradeMajority(address proposal);

    event DocumentMajority(bytes32 proposal);

    struct Poll {
        uint256 start;
        bool[256] voted;
        uint16 yesVotes;
        uint16 noVotes;
        uint256 duration;
        uint256 cooldown;
    }

    uint256 public pollDuration;
    uint256 public pollCooldown;
    uint16 public totalVoters;
    address[] public upgradeProposals;
    mapping(address => Poll) public upgradePolls;
    mapping(address => bool) public upgradeHasAchievedMajority;
    bytes32[] public documentProposals;
    mapping(bytes32 => Poll) public documentPolls;
    mapping(bytes32 => bool) public documentHasAchievedMajority;
    bytes32[] public documentMajorities;

    constructor(uint256 _pollDuration, uint256 _pollCooldown) public {
        reconfigure(_pollDuration, _pollCooldown);
    }

    function reconfigure(uint256 _pollDuration, uint256 _pollCooldown) public onlyOwner {
        require((5 days <= _pollDuration) && (_pollDuration <= 90 days) && (5 days <= _pollCooldown) && (_pollCooldown <= 90 days));
        pollDuration = _pollDuration;
        pollCooldown = _pollCooldown;
    }

    function incrementTotalVoters() external onlyOwner {
        require(totalVoters < 256);
        totalVoters = totalVoters.add(1);
    }

    function getUpgradeProposals() external view returns (address[] proposals) {
        return upgradeProposals;
    }

    function getUpgradeProposalCount() external view returns (uint256 count) {
        return upgradeProposals.length;
    }

    function getDocumentProposals() external view returns (bytes32[] proposals) {
        return documentProposals;
    }

    function getDocumentProposalCount() external view returns (uint256 count) {
        return documentProposals.length;
    }

    function getDocumentMajorities() external view returns (bytes32[] majorities) {
        return documentMajorities;
    }

    function hasVotedOnUpgradePoll(uint8 _galaxy, address _proposal) external view returns (bool result) {
        return upgradePolls[_proposal].voted[_galaxy];
    }

    function hasVotedOnDocumentPoll(uint8 _galaxy, bytes32 _proposal) external view returns (bool result) {
        return documentPolls[_proposal].voted[_galaxy];
    }

    function startUpgradePoll(address _proposal) external onlyOwner {
        require(!upgradeHasAchievedMajority[_proposal]);

        Poll storage poll = upgradePolls[_proposal];

        if (0 == poll.start) {
            upgradeProposals.push(_proposal);
        }

        startPoll(poll);
        emit UpgradePollStarted(_proposal);
    }

    function startDocumentPoll(bytes32 _proposal) external onlyOwner {
        require(!documentHasAchievedMajority[_proposal]);

        Poll storage poll = documentPolls[_proposal];
        if (0 == poll.start) {
            documentProposals.push(_proposal);
        }

        startPoll(poll);
        emit DocumentPollStarted(_proposal);
    }

    function startPoll(Poll storage _poll) internal {
        require(block.timestamp > (_poll.start.add(_poll.duration.add(_poll.cooldown))));
        _poll.start = block.timestamp;
        delete _poll.voted;
        _poll.yesVotes = 0;
        _poll.noVotes = 0;
        _poll.duration = pollDuration;
        _poll.cooldown = pollCooldown;
    }

    function castUpgradeVote(
        uint8 _as,
        address _proposal,
        bool _vote
    ) external onlyOwner returns (bool majority) {
        Poll storage poll = upgradePolls[_proposal];
        processVote(poll, _as, _vote);
        return updateUpgradePoll(_proposal);
    }

    function castDocumentVote(
        uint8 _as,
        bytes32 _proposal,
        bool _vote
    ) external onlyOwner returns (bool majority) {
        Poll storage poll = documentPolls[_proposal];
        processVote(poll, _as, _vote);
        return updateDocumentPoll(_proposal);
    }

    function processVote(
        Poll storage _poll,
        uint8 _as,
        bool _vote
    ) internal {
        assert(block.timestamp >= _poll.start);

        require( //  may only vote once
            //
            !_poll.voted[_as] &&
                //
                //  may only vote when the poll is open
                //
                (block.timestamp < _poll.start.add(_poll.duration))
        );
        _poll.voted[_as] = true;
        if (_vote) {
            _poll.yesVotes = _poll.yesVotes.add(1);
        } else {
            _poll.noVotes = _poll.noVotes.add(1);
        }
    }

    function updateUpgradePoll(address _proposal) public onlyOwner returns (bool majority) {
        require(!upgradeHasAchievedMajority[_proposal]);
        Poll storage poll = upgradePolls[_proposal];
        majority = checkPollMajority(poll);
        if (majority) {
            upgradeHasAchievedMajority[_proposal] = true;
            emit UpgradeMajority(_proposal);
        }
        return majority;
    }

    function updateDocumentPoll(bytes32 _proposal) public returns (bool majority) {
        require(!documentHasAchievedMajority[_proposal]);

        Poll storage poll = documentPolls[_proposal];
        majority = checkPollMajority(poll);
        if (majority) {
            documentHasAchievedMajority[_proposal] = true;
            documentMajorities.push(_proposal);
            emit DocumentMajority(_proposal);
        }
        return majority;
    }

    function checkPollMajority(Poll _poll) internal view returns (bool majority) {
        return ((_poll.yesVotes >= (totalVoters / 4)) &&
            (_poll.yesVotes > _poll.noVotes) &&
            ((block.timestamp > _poll.start.add(_poll.duration)) || (_poll.yesVotes > totalVoters.sub(_poll.yesVotes))));
    }
}
