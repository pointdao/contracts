// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

contract PointTreasury is TimelockController, IERC721Receiver {
    IWETH immutable weth;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address _wethAddress
    ) TimelockController(minDelay, proposers, executors) {
        weth = IWETH(_wethAddress);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override(IERC721Receiver) returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function sweepETH() public {
        weth.deposit{value: address(this).balance}();
    }
}
