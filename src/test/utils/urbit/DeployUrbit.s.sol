// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import {IERC173} from "../../../common/interfaces/IERC173.sol";

contract DeployUrbit is Test {
    event TestEmitOne(address test);
    address public azimuth;
    address public polls;
    address public claims;
    address public ecliptic;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        azimuth = deployCode("Azimuth.sol:Azimuth");
        polls = deployCode("Polls.sol:Polls", abi.encode(uint256(2592000), uint256(2592000)));
        claims = deployCode("Claims.sol:Claims", abi.encode(azimuth));
        ecliptic = deployCode("Ecliptic.sol:Ecliptic", abi.encode(address(0), azimuth, polls, claims, address(0)));
        IERC173(azimuth).transferOwnership(ecliptic);
        IERC173(polls).transferOwnership(ecliptic);
        vm.stopBroadcast();
    }
}
