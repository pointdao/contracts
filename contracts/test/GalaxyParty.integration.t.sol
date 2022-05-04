// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {DSTest} from "../../lib/ds-test/src/test.sol";
import {stdCheats} from "../../lib/forge-std/src/stdlib.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";

import {Deployer} from "../Deployer.sol";
// import {GalaxyParty} from "../GalaxyParty.sol";
// import {GalaxyLocker} from "../GalaxyLocker.sol";
// import {Point} from "../Point.sol";
// import {PointGovernor} from "../PointGovernor.sol";
// import {PointTreasury} from "../PointTreasury.sol";
// import {IEcliptic, IOwnable} from "../urbit/IUrbit.sol";
// import {Vesting} from "../Vesting.sol";
import {MockWallet} from "./utils/MockWallet.sol";
import {MockTreasuryProxy} from "./utils/MockTreasuryProxy.sol";
import {MockWETH} from "./utils/MockWETH.sol";

contract GalaxyPartyTest is DSTest, stdCheats {
    // testing tools
    Vm internal vm;
    // MockWallet internal contributor;
    // MockWallet internal galaxyOwner;
    // MockWallet internal multisig;
    // MockWETH internal weth;

    // // urbit
    // address internal azimuth;
    // address internal polls;
    // address internal claims;
    // address internal ecliptic;

    // // point dao
    // Point internal pointToken;
    // PointGovernor internal pointGovernor;
    // PointTreasury internal pointTreasury;
    // GalaxyParty internal galaxyParty;
    // GalaxyLocker internal galaxyLocker;
    // Vesting internal vesting;

    // uint256 constant GOV_SUPPLY = 10664 * 10**18;

    // event AskCreated(uint256 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    // event AskCanceled(uint256 askId);

    // event SwapInitiated(uint256 swapId, address owner, uint8 point);

    // event SwapCanceled(uint256 swapId);

    // event SwapCompleted(uint256 swapId, address owner, uint8 point);

    // event Contributed(address indexed contributor, uint256 askId, uint256 amount, uint256 remainingUnallocatedEth);

    // event AskSettled(uint256 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    // function setUp() public {
    //     // setup testing tools
    //     vm = Vm(HEVM_ADDRESS);
    //     weth = new MockWETH();
    //     contributor = new MockWallet();
    //     galaxyOwner = new MockWallet();
    //     multisig = new MockWallet();

    //     // setup urbit
    //     azimuth = deployCode("Urbit.sol:Azimuth");
    //     polls = deployCode("Urbit.sol:Polls", abi.encode(uint256(2592000), uint256(2592000)));
    //     claims = deployCode("Urbit.sol:Claims", abi.encode(azimuth));
    //     address treasuryProxy = address(new MockTreasuryProxy());
    //     ecliptic = deployCode("Urbit.sol:Ecliptic", abi.encode(address(0), azimuth, polls, claims, treasuryProxy));
    //     IOwnable(azimuth).transferOwnership(ecliptic);
    //     IOwnable(polls).transferOwnership(ecliptic);
    //     IEcliptic(ecliptic).createGalaxy(0, address(this));
    //     IEcliptic(ecliptic).createGalaxy(1, address(this));
    //     IEcliptic(ecliptic).createGalaxy(2, address(this));
    //     IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 0);
    //     IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 1);
    //     IERC721(ecliptic).safeTransferFrom(address(this), address(galaxyOwner), 2);

    //     // deploy point dao
    //     Deployer d = new Deployer(azimuth, address(multisig), address(weth));
    //     galaxyLocker = d.galaxyLocker();
    //     galaxyParty = d.galaxyParty();
    //     pointToken = d.pointToken();
    //     pointGovernor = d.pointGovernor();
    //     pointTreasury = d.pointTreasury();
    //     vesting = d.vesting();
    // }

    // function test_CompleteGalaxySwap() public {
    //     vm.startPrank(address(galaxyOwner));

    //     uint256 initiatedBlock = block.number;
    //     IERC721(ecliptic).approve(address(galaxyParty), 0);
    //     vm.expectEmit(false, false, false, true);
    //     emit SwapInitiated(1, address(galaxyOwner), 0);
    //     galaxyParty.initiateGalaxySwap(0);
    //     assert(pointToken.totalSupply() == GOV_SUPPLY);
    //     assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);
    //     assertEq(IERC721(ecliptic).ownerOf(0), address(galaxyOwner));

    //     vm.expectEmit(false, false, false, true);
    //     emit SwapCompleted(1, address(galaxyOwner), 0);
    //     vm.roll(initiatedBlock + 1);
    //     galaxyParty.completeGalaxySwap(1);
    //     assert(pointToken.totalSupply() == GOV_SUPPLY + 1000 * 10**18);
    //     assertEq(pointToken.balanceOf(address(galaxyOwner)), 1000 * 10**18);
    //     assertEq(IERC721(ecliptic).ownerOf(0), address(galaxyLocker));
    //     vm.stopPrank();
    // }

    // function test_CancelGalaxySwap() public {
    //     vm.startPrank(address(galaxyOwner));
    //     uint256 initiatedBlock = block.number;
    //     IERC721(ecliptic).approve(address(galaxyParty), 0);
    //     vm.expectEmit(false, false, false, true);
    //     emit SwapInitiated(1, address(galaxyOwner), 0);
    //     galaxyParty.initiateGalaxySwap(0);
    //     assert(pointToken.totalSupply() == GOV_SUPPLY);
    //     assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);
    //     assertEq(IERC721(ecliptic).ownerOf(0), address(galaxyOwner));

    //     vm.expectEmit(false, false, false, true);
    //     emit SwapCanceled(1);
    //     galaxyParty.cancelGalaxySwap(1);
    //     vm.expectRevert("swap must exist and be in INITIATED state");
    //     galaxyParty.completeGalaxySwap(1);
    //     vm.stopPrank();
    // }

    // function test_SuccessfulAskFlow() public {
    //     assert(pointToken.totalSupply() == GOV_SUPPLY);
    //     assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);

    //     // approve ERC721 transfer and create GalaxyAsk
    //     vm.startPrank(address(galaxyOwner));
    //     IERC721(ecliptic).setApprovalForAll(address(galaxyParty), true);
    //     vm.expectEmit(true, true, false, false);
    //     emit AskCreated(1, address(galaxyOwner), 0, 1 * 10**18, 1 * 10**18);
    //     galaxyParty.createAsk(0, 1 * 10**18, 1 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1 POINT, leaving 999 ETH unallocated
    //     vm.stopPrank();

    //     // governance approves ask
    //     vm.prank(address(pointTreasury));
    //     galaxyParty.approveAsk(1);

    //     // contributor contributes ETH to ask (full remaining amount so ask is settled)
    //     vm.deal(address(contributor), 999 * 10**18);
    //     vm.startPrank(address(contributor));
    //     vm.expectEmit(true, false, false, true);
    //     emit Contributed(address(contributor), 1, 999 * 10**18, 0);
    //     vm.expectEmit(false, false, false, true);
    //     emit AskSettled(1, address(galaxyOwner), 0, 999 * 10**18, 1 * 10**18);
    //     galaxyParty.contribute{value: 999 * 10**18}(1, 999 * 10**18);
    //     assertEq(IERC721(ecliptic).ownerOf(0), address(galaxyLocker)); // make sure point treasury gets galaxy
    //     assertEq(address(galaxyOwner).balance, 999 * 10**18); // galaxy owner gets ETH
    //     assert(pointToken.totalSupply() == GOV_SUPPLY + 1 * 10**18);
    //     assertEq(pointToken.balanceOf(address(galaxyOwner)), 1 * 10**18); // galaxyOwner gets correct amount of POINT

    //     // contributor claims POINT
    //     galaxyParty.claim(1);
    //     vm.stopPrank();
    //     assert(pointToken.totalSupply() == GOV_SUPPLY + 1000 * 10**18);
    //     assertEq(pointToken.balanceOf(address(contributor)), 999 * 10**18); // contributor gets POINT

    //     // galaxy owner creates another ask and cancels it
    //     vm.startPrank(address(galaxyOwner));
    //     vm.expectEmit(true, true, false, false);
    //     emit AskCreated(2, address(galaxyOwner), 1, 1 * 10**18, 1 * 10**18);
    //     galaxyParty.createAsk(1, 1 * 10**18, 1 * 10**18);
    //     vm.expectEmit(true, true, false, false);
    //     emit AskCanceled(2);
    //     galaxyParty.cancelAsk(2);
    //     vm.stopPrank();
    // }
}
