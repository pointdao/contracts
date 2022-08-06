// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AppStorage, Modifiers, Checkpoint} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

interface IPointToken {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function checkpoints(address account, uint32 pos) external view returns (Checkpoint memory);

    function numCheckpoints(address account) external view returns (uint32);

    function delegates(address account) external view returns (address);

    function getVotes(address account) external view returns (uint256);

    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;
}
