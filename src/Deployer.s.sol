// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "forge-std/Script.sol";
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

/* Deploys entire protocol atomically */
contract Deployer is Script {
    Diamond public diamond;
    GalaxyPartyFacet public galaxyParty;
    PointTokenFacet public pointToken;
    AdminFacet public admin;
    GalaxyHolderFacet public galaxyHolder;
    Migration0Init public migration;

    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;

    address constant azimuth = 0x223c067F8CF28ae173EE5CafEa60cA44C335fecB;
    address private multisig = 0x691dA55929c47244413d47e82c204BDA834Ee343;
    address private weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        vm.startBroadcast();
        diamond = new Diamond(address(this));

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](4);

        galaxyParty = new GalaxyPartyFacet();
        pointToken = new PointTokenFacet();
        galaxyHolder = new GalaxyHolderFacet();
        admin = new AdminFacet();
        migration = new Migration0Init();

        vm.stopBroadcast();

        bytes4[] memory galaxyPartySelectors = new bytes4[](6);
        galaxyPartySelectors[0] = GalaxyPartyFacet.createAsk.selector;
        galaxyPartySelectors[1] = GalaxyPartyFacet.cancelAsk.selector;
        galaxyPartySelectors[2] = GalaxyPartyFacet.approveAsk.selector;
        galaxyPartySelectors[3] = GalaxyPartyFacet.contribute.selector;
        galaxyPartySelectors[4] = GalaxyPartyFacet.settleAsk.selector;
        galaxyPartySelectors[5] = GalaxyPartyFacet.claim.selector;
        diamondCut[0] = IDiamondCut.FacetCut(address(galaxyParty), IDiamondCut.FacetCutAction.Add, galaxyPartySelectors);

        bytes4[] memory pointTokenSelectors = new bytes4[](17);
        pointTokenSelectors[0] = PointTokenFacet.approve.selector;
        pointTokenSelectors[1] = PointTokenFacet.transfer.selector;
        pointTokenSelectors[2] = PointTokenFacet.transferFrom.selector;
        pointTokenSelectors[3] = PointTokenFacet.totalSupply.selector;
        pointTokenSelectors[4] = PointTokenFacet.balanceOf.selector;
        pointTokenSelectors[5] = PointTokenFacet.allowance.selector;
        pointTokenSelectors[6] = PointTokenFacet.permit.selector;
        pointTokenSelectors[7] = PointTokenFacet.nonces.selector;
        pointTokenSelectors[8] = PointTokenFacet.DOMAIN_SEPARATOR.selector;
        pointTokenSelectors[9] = PointTokenFacet.checkpoints.selector;
        pointTokenSelectors[10] = PointTokenFacet.numCheckpoints.selector;
        pointTokenSelectors[11] = PointTokenFacet.delegates.selector;
        pointTokenSelectors[12] = PointTokenFacet.getVotes.selector;
        pointTokenSelectors[13] = PointTokenFacet.getPastVotes.selector;
        pointTokenSelectors[14] = PointTokenFacet.getPastTotalSupply.selector;
        pointTokenSelectors[15] = PointTokenFacet.delegate.selector;
        pointTokenSelectors[16] = PointTokenFacet.delegateBySig.selector;
        diamondCut[1] = IDiamondCut.FacetCut(address(pointToken), IDiamondCut.FacetCutAction.Add, pointTokenSelectors);

        bytes4[] memory galaxyHolderSelectors = new bytes4[](6);
        galaxyHolderSelectors[0] = GalaxyHolderFacet.setManagementProxy.selector;
        galaxyHolderSelectors[1] = GalaxyHolderFacet.setSpawnProxy.selector;
        galaxyHolderSelectors[2] = GalaxyHolderFacet.setVotingProxy.selector;
        galaxyHolderSelectors[3] = GalaxyHolderFacet.castDocumentVote.selector;
        galaxyHolderSelectors[4] = GalaxyHolderFacet.castUpgradeVote.selector;
        galaxyHolderSelectors[5] = GalaxyHolderFacet.onERC721Received.selector;
        diamondCut[2] = IDiamondCut.FacetCut(address(galaxyHolder), IDiamondCut.FacetCutAction.Add, galaxyHolderSelectors);

        bytes4[] memory adminSelectors = new bytes4[](5);
        adminSelectors[0] = AdminFacet.updateEcliptic.selector;
        adminSelectors[1] = AdminFacet.runMigration.selector;
        adminSelectors[2] = AdminFacet.pauseTokenTransfers.selector;
        adminSelectors[3] = AdminFacet.unpauseTokenTransfers.selector;
        adminSelectors[4] = AdminFacet.setManager.selector;
        diamondCut[3] = IDiamondCut.FacetCut(address(admin), IDiamondCut.FacetCutAction.Add, adminSelectors);

        IDiamondCut(address(diamond)).diamondCut(
            diamondCut,
            address(migration),
            abi.encodeWithSelector(Migration0Init.init.selector, azimuth, multisig)
        );

        // deploy governance
        address[] memory empty = new address[](0);
        vm.startBroadcast();
        pointTreasury = new PointTreasury(86400, empty, empty, weth);
        pointGovernor = new PointGovernor(IVotes(address(diamond)), pointTreasury);
        vm.stopBroadcast();

        // governor can propose, execute and cancel proposals
        pointTreasury.grantRole(pointTreasury.PROPOSER_ROLE(), address(pointGovernor));
        pointTreasury.grantRole(pointTreasury.EXECUTOR_ROLE(), address(pointGovernor));
        pointTreasury.grantRole(pointTreasury.CANCELLER_ROLE(), address(pointGovernor));

        // multisig can cancel proposals and grant/revoke roles
        pointTreasury.grantRole(pointTreasury.CANCELLER_ROLE(), address(multisig));
        pointTreasury.grantRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(multisig));

        // revoke unnecessary admin roles
        pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(pointTreasury));
        pointTreasury.revokeRole(pointTreasury.TIMELOCK_ADMIN_ROLE(), address(this));

        // deploy mint treasury supply
        IAdmin(address(diamond)).runMigration(
            address(migration),
            abi.encodeWithSelector(Migration0Init.initGovernance.selector, address(pointTreasury))
        );

        IERC173(address(diamond)).transferOwnership(multisig);
    }
}
