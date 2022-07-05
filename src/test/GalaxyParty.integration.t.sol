// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DSTest} from "ds-test/test.sol";
import {Test} from "forge-std/Test.sol";

import {Deployer} from "../Deployer.s.sol";
import {Diamond} from "../diamond/Diamond.sol";
import {PointGovernor} from "../governance/PointGovernor.sol";
import {PointTreasury} from "../governance/PointTreasury.sol";
import {IERC173} from "../common/interfaces/IERC173.sol";
import {IEcliptic, IAzimuth} from "../common/interfaces/IUrbit.sol";
import {MockWallet} from "./utils/MockWallet.sol";
import {MockWETH} from "./utils/MockWETH.sol";
import {IGalaxyParty} from "../diamond/interfaces/IGalaxyParty.sol";
import {Deployer} from "../Deployer.s.sol";
import {DeployUrbit} from "./utils/urbit/DeployUrbit.s.sol";

contract GalaxyPartyTest is DSTest, Test {
    // testing tools
    MockWallet internal contributor;
    MockWallet internal galaxyOwner;
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

    event Value(uint256 value);

    event AskCreated(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event AskCanceled(uint16 askId);
    event SwapInitiated(uint16 swapId, address owner, uint8 point);
    event SwapCanceled(uint16 swapId);
    event SwapCompleted(uint16 swapId, address owner, uint8 point);
    event Contributed(address indexed contributor, uint16 askId, uint256 amount, uint256 remainingUnallocatedEth);
    event AskSettled(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event Claimed(address indexed contributor, uint256 tokenAmount, uint256 ethAmount);

    function setUp() public {
        // setup testing tools
        weth = new MockWETH();
        contributor = new MockWallet();
        galaxyOwner = new MockWallet();
        multisig = new MockWallet();

        // setup urbit
        DeployUrbit urbitDeployer = new DeployUrbit();
        urbitDeployer.run();
        azimuth = urbitDeployer.azimuth();
        polls = urbitDeployer.polls();
        claims = urbitDeployer.claims();
        ecliptic = urbitDeployer.ecliptic();
        IEcliptic(ecliptic).createGalaxy(0, address(this));
        IEcliptic(ecliptic).createGalaxy(1, address(this));
        IEcliptic(ecliptic).createGalaxy(2, address(this));
        IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 0);
        IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 1);
        IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 2);

        // deploy governance and protocol
        Deployer d = new Deployer();
        d.runMockSetup(address(azimuth), address(multisig));
        diamond = d.diamond();
        pointGovernor = d.pointGovernor();
        pointTreasury = d.pointTreasury();
    }

    function test_SuccessfulAskFlow() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        vm.expectEmit(true, true, false, false);
        emit AskCreated(1, address(galaxyOwner), 0, 999 * 10**18, 1_000 * 10**18);
        IGalaxyParty(address(diamond)).createAsk(0, 999 * 10**18, 1_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1000 POINT, leaving 999 ETH unallocated
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(pointTreasury));
        IGalaxyParty(address(diamond)).approveAsk(1);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 999 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, false, false, true);
        emit Contributed(address(contributor), 1, 999 * 10**18, 0);
        IGalaxyParty(address(diamond)).contribute{value: 999 * 10**18}(1);
        vm.expectEmit(false, false, false, true);
        emit AskSettled(1, address(galaxyOwner), 0, 96903 * 10**16, 1_000 * 10**18);
        IGalaxyParty(address(diamond)).settleAsk(1);
        assertEq(IERC721(ecliptic).ownerOf(0), address(diamond));
        assertEq(address(galaxyOwner).balance, 96903 * 10**16); // 979.02 eth, 97% of 999 raised
        assertEq(address(pointTreasury).balance, 2997 * 10**16); // 29.97 eth, 3% of 999 raised
        assertEq(IERC20(address(diamond)).balanceOf(address(galaxyOwner)), 1_000 * 10**18); // galaxyOwner gets correct amount of POINT
        assertEq(IERC20(address(diamond)).balanceOf(address(pointTreasury)), 30_000 * 10**18);
        assertEq(IERC20(address(diamond)).totalSupply(), 31_000 * 10**18);
        // contributor claims POINT
        vm.expectEmit(true, false, false, true);
        emit Claimed(address(contributor), 999_000 * 10**18, 0);
        IGalaxyParty(address(diamond)).claim(1);
        vm.stopPrank();
        assert(IERC20(address(diamond)).totalSupply() == 1_030_000 * 10**18);
        assertEq(IERC20(address(diamond)).balanceOf(address(contributor)), 999_000 * 10**18);
        // galaxy owner creates another ask and cancels it
        vm.startPrank(address(galaxyOwner));
        vm.expectEmit(true, true, false, false);
        emit AskCreated(2, address(galaxyOwner), 1, 999 * 10**18, 1_000 * 10**18);
        IGalaxyParty(address(diamond)).createAsk(1, 999 * 10**18, 1_000 * 10**18);
        vm.expectEmit(true, true, false, false);
        emit AskCanceled(2);
        IGalaxyParty(address(diamond)).cancelAsk(2);
        vm.stopPrank();
        // someone tries to contribute to ended ask
        vm.deal(address(contributor), 1 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectRevert("ask must be in approved state");
        IGalaxyParty(address(diamond)).contribute{value: 1 * 10**18}(1);
        vm.stopPrank();
        // someone tries to contribute to canceled ask
        vm.startPrank(address(contributor));
        vm.expectRevert("ask must be in approved state");
        IGalaxyParty(address(diamond)).contribute{value: 1 * 10**18}(2);
        vm.stopPrank();
    }

    function test_SuccessfulAskFlowNoETH() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        vm.expectEmit(true, true, false, false);
        emit AskCreated(1, address(galaxyOwner), 0, 0, 1_000_000 * 10**18);
        IGalaxyParty(address(diamond)).createAsk(0, 0 * 10**18, 1_000_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1000 POINT, leaving 999 ETH unallocated
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(pointTreasury));
        IGalaxyParty(address(diamond)).approveAsk(1);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 1);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, false, false, true);
        vm.expectRevert("msg.value is greater than remaining amount");
        IGalaxyParty(address(diamond)).contribute{value: 1}(1);
        emit AskSettled(1, address(galaxyOwner), 0, 0, 1_000_000 * 10**18);
        IGalaxyParty(address(diamond)).settleAsk(1);
        assertEq(IERC721(ecliptic).ownerOf(0), address(diamond));
        assertEq(address(galaxyOwner).balance, 0);
        assertEq(address(pointTreasury).balance, 0);
        assertEq(IERC20(address(diamond)).balanceOf(address(galaxyOwner)), 1_000_000 * 10**18); // galaxyOwner gets correct amount of POINT
        assertEq(IERC20(address(diamond)).balanceOf(address(pointTreasury)), 30_000 * 10**18);
        assertEq(IERC20(address(diamond)).totalSupply(), 1_030_000 * 10**18);
    }
}
