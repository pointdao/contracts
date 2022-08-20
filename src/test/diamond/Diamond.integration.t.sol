// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {DSTest} from "ds-test/test.sol";
import {Test} from "forge-std/Test.sol";

import {Deployer} from "../../Deployer.s.sol";
import {Diamond} from "../../diamond/Diamond.sol";
import {PointGovernor} from "../../governance/PointGovernor.sol";
import {PointTreasury} from "../../governance/PointTreasury.sol";
import {IERC173} from "../../common/interfaces/IERC173.sol";
import {IEcliptic, IAzimuth} from "../../common/interfaces/IUrbit.sol";
import {MockWallet} from "../utils/MockWallet.sol";
import {MockWETH} from "../utils/MockWETH.sol";
import {IGalaxyParty} from "../../diamond/interfaces/IGalaxyParty.sol";
import {IPointToken} from "../../diamond/interfaces/IPointToken.sol";
import {Deployer} from "../../Deployer.s.sol";
import {DeployUrbit} from "../utils/urbit/DeployUrbit.s.sol";
import {Ask, AskStatus} from "../../diamond/libraries/LibAppStorage.sol";
import {IDiamondCut} from "../../diamond/interfaces/IDiamondCut.sol";
import {MockFacet} from "./MockFacet.sol";
import {MockMigration1Init} from "./MockMigration1Init.sol";
import {IMockFacet} from "./IMockFacet.sol";

contract DiamondTest is DSTest, Test {
    // testing tools
    MockWallet internal multisig;
    MockWETH internal weth;

    // urbit
    address internal azimuth;
    address internal polls;
    address internal claims;
    address internal ecliptic;

    // protocol
    Deployer internal deployer;
    Diamond internal diamond;

    // governance
    PointGovernor internal pointGovernor;
    PointTreasury internal pointTreasury;

    IGalaxyParty internal galaxyParty;
    IPointToken internal pointToken;

    function setUp() public {
        // setup testing tools
        weth = new MockWETH();
        multisig = new MockWallet();

        // setup urbit
        DeployUrbit urbitDeployer = new DeployUrbit();
        urbitDeployer.run();
        azimuth = urbitDeployer.azimuth();
        polls = urbitDeployer.polls();
        claims = urbitDeployer.claims();
        ecliptic = urbitDeployer.ecliptic();

        // deploy governance and protocol
        Deployer d = new Deployer();
        d.runMockSetup(address(azimuth), address(multisig));
        diamond = d.diamond();
        galaxyParty = IGalaxyParty(address(diamond));
        pointToken = IPointToken(address(diamond));
        pointGovernor = d.pointGovernor();
        pointTreasury = d.pointTreasury();
    }

    function test_SuccessfulNewFacet() public {
        assertEq(pointToken.name(), "Point DAO");
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        MockFacet facet = new MockFacet();
        MockMigration1Init init = new MockMigration1Init();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.modifyNewField.selector;
        selectors[1] = MockFacet.getNewField.selector;
        selectors[2] = MockFacet.modifyTokenName.selector;
        diamondCut[0] = IDiamondCut.FacetCut(address(facet), IDiamondCut.FacetCutAction.Add, selectors);
        vm.prank(address(multisig));
        IDiamondCut(address(diamond)).diamondCut(diamondCut, address(init), abi.encodeWithSelector(MockMigration1Init.init.selector));
        IMockFacet mockFacet = IMockFacet(address(diamond));

        assertEq(pointToken.name(), "New facet initialized");
        assertEq(mockFacet.getNewField(0), true);
        assertEq(mockFacet.getNewField(1), false);
        mockFacet.modifyNewField(1);
        assertEq(mockFacet.getNewField(1), true);
        mockFacet.modifyTokenName("New token name");
        assertEq(pointToken.name(), "New token name");
    }
}
