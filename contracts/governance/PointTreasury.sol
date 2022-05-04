// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract PointTreasury is TimelockController {
    IWETH immutable weth;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address _wethAddress
    ) TimelockController(minDelay, proposers, executors) {
        weth = IWETH(_wethAddress);
    }

    function sweepETH() public {
        weth.deposit{value: address(this).balance}();
    }
}
