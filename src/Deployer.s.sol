// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Diamond} from "./diamond/Diamond.sol";
import {AdminFacet} from "./diamond/facets/AdminFacet.sol";
import {GalaxyHolderFacet} from "./diamond/facets/GalaxyHolderFacet.sol";
import {GalaxyPartyFacet} from "./diamond/facets/GalaxyPartyFacet.sol";
import {PointTokenFacet} from "./diamond/facets/PointTokenFacet.sol";
import {IDiamondCut} from "./diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./diamond/interfaces/IDiamondLoupe.sol";
import {IAdmin} from "./diamond/interfaces/IAdmin.sol";
import {IERC173} from "./common/interfaces/IERC173.sol";
import {PointGovernor} from "./governance/PointGovernor.sol";
import {PointTreasury} from "./governance/PointTreasury.sol";
import {Migration0Init} from "./diamond/migrations/Migration0Init.sol";
import {Initializer} from "./Initializer.sol";
import {IOwnable} from "./diamond/interfaces/IOwnable.sol";

/* Deploys entire protocol - This is a script, it is not meant to be deployed */
contract Deployer is Script, Ownable {
    Diamond public diamond;
    GalaxyPartyFacet public galaxyParty;
    PointTokenFacet public pointToken;
    AdminFacet public admin;
    GalaxyHolderFacet public galaxyHolder;
    Migration0Init public migration;
    Initializer public initializer;

    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;

    // rinkeby addrs
    address private constant azimuth = 0xC6Fe03489FAd98B949b6a8b37229974908dD9390;
    address private constant multisig = 0xF87805a8cB1f7C9f061c89243D11a427358b6df7;
    address private constant weth = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    // // mainnet addrs
    // address private constant azimuth = 0x223c067F8CF28ae173EE5CafEa60cA44C335fecB;
    // address private constant multisig = 0x691dA55929c47244413d47e82c204BDA834Ee343;
    // address private constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // only for usage with `forge script`
    function run() external {
        vm.startBroadcast();

        diamond = new Diamond(msg.sender);
        galaxyParty = new GalaxyPartyFacet();
        pointToken = new PointTokenFacet();
        galaxyHolder = new GalaxyHolderFacet();
        admin = new AdminFacet();
        migration = new Migration0Init();
        initializer = new Initializer();

        // deploy governance
        address[] memory empty = new address[](0);
        pointTreasury = new PointTreasury(86400, empty, empty, weth);
        pointGovernor = new PointGovernor(IVotes(address(diamond)), pointTreasury);
        pointTreasury.grantRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(initializer));
        pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), msg.sender);

        // initialize protocol
        IERC173(address(diamond)).transferOwnership(address(initializer));
        initializer.setAddresses(diamond, galaxyParty, pointToken, admin, galaxyHolder, migration, pointGovernor, pointTreasury, multisig, azimuth);

        initializer.run();

        vm.stopBroadcast();
    }

    // only for local test setup
    function runMockSetup(address testAzimuth, address testMultisig) public {
        diamond = new Diamond(address(this));
        galaxyParty = new GalaxyPartyFacet();
        pointToken = new PointTokenFacet();
        galaxyHolder = new GalaxyHolderFacet();
        admin = new AdminFacet();
        migration = new Migration0Init();
        initializer = new Initializer();

        // deploy governance
        address[] memory empty = new address[](0);
        pointTreasury = new PointTreasury(86400, empty, empty, weth);
        pointGovernor = new PointGovernor(IVotes(address(diamond)), pointTreasury);
        pointTreasury.grantRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(initializer));
        pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(this));

        // initialize protocol
        IERC173(address(diamond)).transferOwnership(address(initializer));
        initializer.setAddresses(
            diamond,
            galaxyParty,
            pointToken,
            admin,
            galaxyHolder,
            migration,
            pointGovernor,
            pointTreasury,
            testMultisig,
            testAzimuth
        );
        initializer.run();
    }
}
