// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC173} from "../../common/interfaces/IERC173.sol";
import {IEcliptic, IAzimuth} from "../../common/interfaces/IUrbit.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {LibMeta} from "../../diamond/libraries/LibMeta.sol";

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
    uint256 ethAmount;
    uint256 pointAmount;
    uint256 totalContributedToParty;
    uint8 galaxyTokenId;
    AskStatus status;
}

struct MockNewAppStorage {
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
    mapping(uint256 => bool) test;
}
