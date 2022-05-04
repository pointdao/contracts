// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IEcliptic, IAzimuth} from "../interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {IERC173} from "../interfaces/IERC173.sol";

contract Migration0Init {
    AppStorage internal s;

    function go(address azimuth, address vesting) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        s.token.name = "Point DAO";
        s.token.symbol = "POINT";
        s.token.decimals = 18;
        s.token.maxSupply = 266_664_000 * 10**18;
        s.token.PARTY_AMOUNT = 1_000_000 * 10**18;
        s.token.INITIAL_CHAIN_ID = block.chainid;
        s.token.INITIAL_DOMAIN_SEPARATOR = LibPointToken.computeDomainSeparator();
        s.token.paused = true;
        s.token._DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
        LibPointToken.mint(vesting, 10_664_000);
        bytes32 hashedName = keccak256(bytes(s.token.name));
        bytes32 hashedVersion = keccak256(bytes("1"));
        bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        // s.token._HASHED_NAME = hashedName;
        // s.token._HASHED_VERSION = hashedVersion;
        // s.token._CACHED_CHAIN_ID = block.chainid;
        // s.token._CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
        // s.token._CACHED_THIS = address(this);
        // s.token._TYPE_HASH = typeHash;

        s.urbit.azimuth = IAzimuth(azimuth);
        LibUrbit.updateEcliptic(s);

        s.galaxyParty.SELLER_POINT_INCREMENT = 10**18;
        s.galaxyParty.SELLER_ETH_PER_POINT_INCREMENT = 10**15;
        s.galaxyParty.CONTRIBUTOR_POINT_INCREMENT = 10**15;

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20).interfaceId] = true;
    }
}
