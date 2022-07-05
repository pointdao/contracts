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
import {IEcliptic, IAzimuth} from "../../common/interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {IERC173} from "../../common/interfaces/IERC173.sol";

contract Migration0Init {
    AppStorage internal s;

    function init(
        address azimuth,
        address multisig,
        address governance
    ) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        s.multisig = multisig;

        s.tokenName = "Point DAO";
        s.tokenSymbol = "POINT";
        s.tokenDecimals = 18;
        s.tokenMaxSupply = type(uint224).max;

        s.INITIAL_CHAIN_ID = block.chainid;
        s.INITIAL_DOMAIN_SEPARATOR = LibPointToken.computeDomainSeparator();
        s.tokenPaused = true;
        s.token_DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

        s.azimuth = IAzimuth(azimuth);
        LibUrbit.updateEcliptic(s);

        s.galaxyParty_TREASURY_POINT_INFLATION_BPS = 300;
        s.galaxyParty_TREASURY_ETH_FEE_BPS = 300;
        s.galaxyParty_TOKEN_SCALE = 1000;

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20).interfaceId] = true;

        s.governance = governance;
    }
}
