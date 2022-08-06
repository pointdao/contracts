// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
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
import {IPointToken} from "../diamond/interfaces/IPointToken.sol";
import {Deployer} from "../Deployer.s.sol";
import {DeployUrbit} from "./utils/urbit/DeployUrbit.s.sol";
import {Ask, AskStatus} from "../diamond/libraries/LibAppStorage.sol";

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

    IGalaxyParty internal galaxyParty;
    IPointToken internal pointToken;

    event AskCreated(uint16 indexed askId, Ask ask);
    event AskPriceUpdated(uint16 indexed askId, Ask ask, uint256 prevAmount, uint256 prevPointAmount);
    event AskCanceled(uint16 indexed askId, Ask ask, address canceler, AskStatus prevStatus);
    event AskApproved(uint16 indexed askId, Ask ask);
    event Claimed(uint16 indexed askId, address indexed contributor, uint256 pointAmount, uint256 ethAmount);
    event Contributed(uint16 indexed askId, address indexed contributor, Ask ask, uint256 amount);
    event AskSettled(uint16 indexed askId, Ask ask);
    event ETHTransferFailed(uint16 indexed askId, address intended, uint256 amount);

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
        galaxyParty = IGalaxyParty(address(diamond));
        pointToken = IPointToken(address(diamond));
        pointGovernor = d.pointGovernor();
        pointTreasury = d.pointTreasury();
    }

    function test_SuccessfulAskFlow() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        vm.expectEmit(true, false, false, false);
        emit AskCreated(1, Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 0, 0, AskStatus.CREATED));
        galaxyParty.createAsk(0, 999 * 10**18, 1_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1000 POINT, leaving 999 ETH unallocated
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(pointTreasury));
        galaxyParty.approveAsk(1, 999 * 10**18, 1_000 * 10**18);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 999 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, true, false, true);
        emit Contributed(
            1,
            address(contributor),
            Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 999 * 10**18, 0, AskStatus.APPROVED),
            999 * 10**18
        );
        galaxyParty.contribute{value: 999 * 10**18}(1);
        vm.expectEmit(true, false, false, true);
        emit AskSettled(1, Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 999 * 10**18, 0, AskStatus.ENDED));
        galaxyParty.settleAsk(1);
        assertEq(IERC721(ecliptic).ownerOf(0), address(diamond));
        assertEq(address(galaxyOwner).balance, 96903 * 10**16); // 979.02 eth, 97% of 999 raised
        assertEq(address(pointTreasury).balance, 2997 * 10**16); // 29.97 eth, 3% of 999 raised
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1_000 * 10**18); // galaxyOwner gets correct amount of POINT
        assertEq(pointToken.balanceOf(address(pointTreasury)), 30_000 * 10**18);
        assertEq(pointToken.totalSupply(), 31_000 * 10**18);
        // contributor claims POINT
        vm.expectEmit(true, true, false, true);
        emit Claimed(1, address(contributor), 999_000 * 10**18, 0);
        galaxyParty.claim(1);
        vm.stopPrank();
        assert(pointToken.totalSupply() == 1_030_000 * 10**18);
        assertEq(pointToken.balanceOf(address(contributor)), 999_000 * 10**18);
        // galaxy owner creates another ask and cancels it
        vm.startPrank(address(galaxyOwner));
        vm.expectEmit(true, false, false, false);
        emit AskCreated(2, Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 0, 1, AskStatus.CREATED));
        galaxyParty.createAsk(1, 999 * 10**18, 1_000 * 10**18);
        vm.expectEmit(true, false, false, false);
        emit AskCanceled(
            2,
            Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 0, 1, AskStatus.CANCELED),
            address(galaxyOwner),
            AskStatus.CREATED
        );
        galaxyParty.cancelAsk(2);
        vm.stopPrank();
        // someone tries to contribute to ended ask
        vm.deal(address(contributor), 1 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectRevert("ask must be in approved state");
        galaxyParty.contribute{value: 1 * 10**18}(1);
        vm.stopPrank();
        // someone tries to contribute to canceled ask
        vm.startPrank(address(contributor));
        vm.expectRevert("ask must be in approved state");
        galaxyParty.contribute{value: 1 * 10**18}(2);
        vm.stopPrank();
    }

    function test_AskPriceUpdated() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        vm.expectEmit(true, false, false, false);
        emit AskCreated(1, Ask(address(galaxyOwner), 999 * 10**18, 1_000 * 10**18, 0, 0, AskStatus.CREATED));
        galaxyParty.createAsk(0, 999 * 10**18, 1_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1000 POINT, leaving 999 ETH unallocated
        vm.expectEmit(true, false, false, false);
        // galaxy owner updates ask price
        emit AskPriceUpdated(1, Ask(address(galaxyOwner), 1_000 * 10**18, 0, 0, 0, AskStatus.CREATED), 999 * 10**18, 1_000 * 10**18);
        galaxyParty.updateAskPrice(1, 1_000 * 10**18, 0);
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(pointTreasury));
        galaxyParty.approveAsk(1, 1_000 * 10**18, 0);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 1_000 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, true, false, true);
        emit Contributed(
            1,
            address(contributor),
            Ask(address(galaxyOwner), 1_000 * 10**18, 0, 1_000 * 10**18, 0, AskStatus.APPROVED),
            1_000 * 10**18
        );
        galaxyParty.contribute{value: 1_000 * 10**18}(1);
        vm.expectEmit(true, false, false, true);
        emit AskSettled(1, Ask(address(galaxyOwner), 1_000 * 10**18, 0, 1_000 * 10**18, 0, AskStatus.ENDED));
        galaxyParty.settleAsk(1);
        assertEq(IERC721(ecliptic).ownerOf(0), address(diamond));
        assertEq(address(galaxyOwner).balance, 970 * 10**18);
        assertEq(address(pointTreasury).balance, 30 * 10**18);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);
        assertEq(pointToken.balanceOf(address(pointTreasury)), 30_000 * 10**18);
        assertEq(pointToken.totalSupply(), 30_000 * 10**18);
        // contributor claims POINT
        vm.expectEmit(true, true, false, true);
        emit Claimed(1, address(contributor), 1_000_000 * 10**18, 0);
        galaxyParty.claim(1);
        vm.stopPrank();
        assert(pointToken.totalSupply() == 1_030_000 * 10**18);
        assertEq(pointToken.balanceOf(address(contributor)), 1_000_000 * 10**18);
    }

    function test_SuccessfulAskFlowNoETH() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        vm.expectEmit(true, false, false, false);
        emit AskCreated(1, Ask(address(galaxyOwner), 0, 1_000_000 * 10**18, 0, 0, AskStatus.CREATED));
        galaxyParty.createAsk(0, 0, 1_000_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1,000,000 POINT, leaving 0 ETH unallocated
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(pointTreasury));
        galaxyParty.approveAsk(1, 0, 1_000_000 * 10**18);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 1);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, false, false, true);
        vm.expectRevert("msg.value is greater than remaining amount");
        galaxyParty.contribute{value: 1}(1);
        emit AskSettled(1, Ask(address(galaxyOwner), 0, 1_000_000 * 10**18, 0, 0, AskStatus.ENDED));

        galaxyParty.settleAsk(1);
        assertEq(IERC721(ecliptic).ownerOf(0), address(diamond));
        assertEq(address(galaxyOwner).balance, 0);
        assertEq(address(pointTreasury).balance, 0);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1_000_000 * 10**18); // galaxyOwner gets correct amount of POINT
        assertEq(pointToken.balanceOf(address(pointTreasury)), 30_000 * 10**18);
        assertEq(pointToken.totalSupply(), 1_030_000 * 10**18);
    }

    function test_SuccessfulAskFlowAndGovernanceVote() public {
        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        IERC721(ecliptic).setApprovalForAll(address(diamond), true);
        galaxyParty.createAsk(0, 999 * 10**18, 1_000 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1000 POINT, leaving 999 ETH unallocated
        vm.stopPrank();
        // governance approves ask
        vm.prank(address(multisig));
        galaxyParty.approveAsk(1, 999 * 10**18, 1_000 * 10**18);
        // contributor contributes ETH to ask and settles ask
        vm.deal(address(contributor), 999 * 10**18);
        vm.startPrank(address(contributor));
        galaxyParty.contribute{value: 999 * 10**18}(1);
        galaxyParty.settleAsk(1);
        // contributor claims POINT
        galaxyParty.claim(1);
        uint256 claimBlockNumber = block.number;
        assertEq(pointToken.balanceOf(address(contributor)), 999_000 * 10**18);
        pointToken.delegate(address(contributor));
        vm.stopPrank();

        //////////// APPROVE ASK VIA GOVERNANCE ////////////
        uint256 proposeBlockNumber = claimBlockNumber + 1;
        vm.roll(proposeBlockNumber);
        assertEq(pointGovernor.getVotes(address(contributor), claimBlockNumber), 999_000 * 10**18);
        // galaxy owner creates another ask
        vm.prank(address(galaxyOwner));
        galaxyParty.createAsk(1, 999 * 10**18, 1_000 * 10**18);
        // contributor with POINT balance proposas ask approval
        vm.startPrank(address(contributor));
        address[] memory targets = new address[](1);
        targets[0] = address(diamond);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(IGalaxyParty.approveAsk.selector, 2, 999 * 10**18, 1_000 * 10**18);
        string memory description = "";
        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 proposalId = pointGovernor.propose(targets, values, calldatas, "");
        uint256 votingStartsBlockNumber = proposeBlockNumber + 2;
        vm.roll(votingStartsBlockNumber);
        assertEq(uint8(pointGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active));
        pointGovernor.castVote(proposalId, 1);
        vm.stopPrank();
        uint256 votingPeriodOverBlock = proposeBlockNumber + 137455 + 1;
        assertEq(pointGovernor.proposalDeadline(proposalId), votingPeriodOverBlock);
        // uint256 executionDelayOverBlock = votingDelayOverBlock + 86400 + 1;
        uint256 queueBlock = votingPeriodOverBlock + 1;
        vm.roll(queueBlock);
        assertEq(uint8(pointGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
        pointGovernor.queue(targets, values, calldatas, descriptionHash);
        uint256 executionDelayOverBlock = queueBlock + 86400 + 1;
        vm.warp(executionDelayOverBlock);
        pointGovernor.execute(targets, values, calldatas, descriptionHash);

        //////////// APPROVE ASK VIA GOVERNANCE ////////////
        vm.deal(address(contributor), 999 * 10**18);
        vm.startPrank(address(contributor));
        galaxyParty.contribute{value: 999 * 10**18}(2);
        galaxyParty.settleAsk(2);
        galaxyParty.claim(2);
        assertEq(pointToken.balanceOf(address(contributor)), 2 * 999_000 * 10**18);
    }
}
