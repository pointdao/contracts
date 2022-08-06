// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IGalaxyParty {
    function lastAskId() external view;

    function getAsk(uint16 _askId) external view;

    function updateAskPrice(
        uint16 _askId,
        uint256 _ethAmount,
        uint256 _pointAmount
    ) external;

    function initiateGalaxySwap(uint8 _point) external;

    function completeGalaxySwap(uint16 _swapId) external;

    function cancelGalaxySwap(uint16 _swapId) external;

    function createAsk(
        uint8 _point,
        uint256 _ethAmount,
        uint256 _pointAmount
    ) external;

    function cancelAsk(uint16 _askId) external;

    function approveAsk(
        uint16 _askId,
        uint256 _ethAmount,
        uint256 _pointAmount
    ) external;

    function contribute(uint16 _askId) external payable;

    function settleAsk(uint16 _askId) external;

    function claim(uint16 _askId) external;
}
