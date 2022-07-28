// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC173} from "../../common/interfaces/IERC173.sol";
import {IEcliptic, IAzimuth} from "../../common/interfaces/IUrbit.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibMeta} from "./LibMeta.sol";

// Token

struct Checkpoint {
    uint32 fromBlock;
    uint224 votes;
}

enum AskStatus {
    NONE,
    CREATED,
    APPROVED,
    CANCELED,
    ENDED
}

struct Ask {
    address owner;
    uint256 amount;
    uint256 pointAmount;
    uint256 totalContributedToParty;
    uint8 point;
    AskStatus status;
}

struct AppStorage {
    address governance;
    address multisig;
    address manager;
    string tokenName;
    string tokenSymbol;
    uint8 tokenDecimals;
    uint256 tokenMaxSupply;
    uint256 tokenTotalSupply;
    mapping(address => uint256) tokenBalanceOf;
    mapping(address => mapping(address => uint256)) tokenAllowance;
    uint256 INITIAL_CHAIN_ID;
    bytes32 INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) tokenNonces;
    bool tokenPaused;
    bytes32 token_DELEGATION_TYPEHASH;
    mapping(address => address) tokenDelegates;
    mapping(address => Checkpoint[]) token_checkpoints;
    Checkpoint[] token_totalSupplyCheckpoints;
    IAzimuth azimuth;
    IEcliptic ecliptic;
    uint16 galaxyPartyAskIds;
    uint16 galaxyPartyLastApprovedAskId;
    mapping(uint16 => Ask) galaxyPartyAsks;
    // ask id -> address -> total contributed
    mapping(uint16 => mapping(address => uint256)) galaxyPartyTotalContributed;
    // ask id -> whether user has claimed yet
    mapping(uint16 => mapping(address => bool)) galaxyPartyClaimed;
    uint16 galaxyParty_TREASURY_POINT_INFLATION_BPS;
    uint16 galaxyParty_TREASURY_ETH_FEE_BPS;
    uint32 galaxyParty_TOKEN_SCALE;
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
        require(!s.tokenPaused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(s.tokenPaused, "Pausable: not paused");
        _;
    }

    // Ownable
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyGovernance() {
        address sender = LibMeta.msgSender();
        require(sender == s.governance, "Only governance can call this function");
        _;
    }

    modifier onlyGovernanceOrOwner() {
        address sender = LibMeta.msgSender();
        require(sender == s.governance || sender == LibDiamond.contractOwner(), "LibAppStorage: Do not have access");
        _;
    }

    modifier onlyGovernanceOrOwnerOrMultisig() {
        address sender = LibMeta.msgSender();
        require(sender == s.governance || sender == LibDiamond.contractOwner() || sender == s.multisig, "LibAppStorage: Do not have access");
        _;
    }
    modifier onlyGovernanceOrOwnerOrMultisigOrManager() {
        address sender = LibMeta.msgSender();
        require(
            sender == s.governance || sender == LibDiamond.contractOwner() || sender == s.multisig || sender == s.manager,
            "LibAppStorage: Do not have access"
        );
        _;
    }
}
