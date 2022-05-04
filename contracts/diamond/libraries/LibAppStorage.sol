// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IEcliptic, IAzimuth} from "../interfaces/IUrbit.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibMeta} from "./LibMeta.sol";

// Token

struct Checkpoint {
    uint32 fromBlock;
    uint224 votes;
}

struct TokenStorage {
    string name;
    string symbol;
    uint8 decimals;
    uint256 maxSupply;
    uint256 totalSupply;
    mapping(address => uint256) balanceOf;
    mapping(address => mapping(address => uint256)) allowance;
    uint256 INITIAL_CHAIN_ID;
    bytes32 INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) nonces;
    bool paused;
    bytes32 _DELEGATION_TYPEHASH;
    mapping(address => address) _delegates;
    mapping(address => Checkpoint[]) _checkpoints;
    Checkpoint[] _totalSupplyCheckpoints;
    uint256 PARTY_AMOUNT;
    // bytes32 _CACHED_DOMAIN_SEPARATOR;
    // uint256 _CACHED_CHAIN_ID;
    // address _CACHED_THIS;
    // bytes32 _HASHED_NAME;
    // bytes32 _HASHED_VERSION;
    // bytes32 _TYPE_HASH;
}

// Urbit

struct UrbitStorage {
    IAzimuth azimuth;
    IEcliptic ecliptic;
}

// GalaxyParty

enum AskStatus {
    NONE,
    CREATED,
    APPROVED,
    CANCELED,
    ENDED
}

enum SwapStatus {
    NONE,
    INITIATED,
    CANCELED,
    COMPLETE
}

struct Ask {
    address owner;
    uint256 amount;
    uint256 pointAmount;
    uint256 totalContributedToParty;
    uint8 point;
    AskStatus status;
}

struct Swap {
    address owner;
    uint8 point;
    uint256 initiatedBlock;
    SwapStatus status;
}

struct GalaxyPartyStorage {
    uint16 askIds;
    uint16 swapIds;
    uint16 lastApprovedAskId;
    mapping(uint16 => Ask) asks;
    mapping(uint16 => Swap) swaps;
    // ask id -> address -> total contributed
    mapping(uint16 => mapping(address => uint256)) totalContributed;
    // ask id -> whether user has claimed yet
    mapping(uint16 => mapping(address => bool)) claimed;
    uint256 SELLER_POINT_INCREMENT;
    uint256 SELLER_ETH_PER_POINT_INCREMENT;
    uint256 CONTRIBUTOR_POINT_INCREMENT;
}

struct GovernanceStorage {
    address payable governance;
    address payable multisig;
    address payable manager;
}

struct AppStorage {
    TokenStorage token;
    UrbitStorage urbit;
    GalaxyPartyStorage galaxyParty;
    GovernanceStorage governance;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}

contract Modifiers {
    AppStorage internal s;

    // Pausable
    modifier whenNotPaused() {
        require(!s.token.paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(s.token.paused, "Pausable: not paused");
        _;
    }

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyGovernance() {
        address sender = LibMeta.msgSender();
        require(sender == s.governance.governance, "Only governance can call this function");
        _;
    }

    modifier onlyGovernanceOrOwner() {
        address sender = LibMeta.msgSender();
        require(sender == s.governance.governance || sender == LibDiamond.contractOwner(), "LibAppStorage: Do not have access");
        _;
    }

    modifier onlyGovernanceOrOwnerOrMultisig() {
        address sender = LibMeta.msgSender();
        require(
            sender == s.governance.governance || sender == LibDiamond.contractOwner() || sender == s.governance.multisig,
            "LibAppStorage: Do not have access"
        );
        _;
    }
    modifier onlyGovernanceOrOwnerOrMultisigOrManager() {
        address sender = LibMeta.msgSender();
        require(
            sender == s.governance.governance ||
                sender == LibDiamond.contractOwner() ||
                sender == s.governance.multisig ||
                sender == s.governance.manager,
            "LibAppStorage: Do not have access"
        );
        _;
    }
}
