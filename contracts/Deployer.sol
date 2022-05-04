// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Diamond} from "./diamond/Diamond.sol";
import {AdminFacet} from "./diamond/facets/AdminFacet.sol";
import {GalaxyHolderFacet} from "./diamond/facets/GalaxyHolderFacet.sol";
import {GalaxyPartyFacet} from "./diamond/facets/GalaxyPartyFacet.sol";
import {PointTokenFacet} from "./diamond/facets/PointTokenFacet.sol";
import {IDiamondCut} from "./diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "./diamond/interfaces/IERC173.sol";
import {PointGovernor} from "./governance/PointGovernor.sol";
import {PointTreasury} from "./governance/PointTreasury.sol";
import {Vesting} from "./governance/Vesting.sol";

/* Deploys entire protocol atomically */
contract Deployer {
    Diamond public diamond;
    GalaxyPartyFacet public galaxyParty;
    PointTokenFacet public pointToken;
    AdminFacet public admin;
    GalaxyHolderFacet public galaxyHolder;

    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;
    Vesting public vesting;

    constructor(
        address azimuth,
        address multisig,
        address weth
    ) {
        diamond = new Diamond(address(this));

        // diamond.pointToken = new Point();

        // // token

        // // deploy governance
        // address[] memory empty = new address[](0);
        // pointTreasury = new PointTreasury(86400, empty, empty, weth);
        // pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // // governor can propose, execute and cancel proposals
        // pointTreasury.grantRole(pointTreasury.PROPOSER_ROLE(), address(pointGovernor));
        // pointTreasury.grantRole(pointTreasury.EXECUTOR_ROLE(), address(pointGovernor));
        // pointTreasury.grantRole(pointTreasury.CANCELLER_ROLE(), address(pointGovernor));

        // // multisig can cancel proposals and grant/revoke roles
        // pointTreasury.grantRole(pointTreasury.CANCELLER_ROLE(), address(multisig));
        // pointTreasury.grantRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(multisig));

        // // revoke unnecessary admin roles
        // pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(pointTreasury));
        // pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(this));

        // // deployer galaxy managers (point minter and burner)
        // galaxyLocker = new GalaxyLocker(pointToken, azimuth, address(pointTreasury));
        // galaxyParty = new GalaxyParty(azimuth, multisig, pointToken, galaxyLocker, payable(address(pointTreasury)));

        // // initialize token
        // vesting = new Vesting(pointTreasury);
        // pointToken.init(pointTreasury, vesting, galaxyParty, galaxyLocker);
    }
}
