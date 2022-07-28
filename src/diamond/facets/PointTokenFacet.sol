// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {AppStorage, Modifiers, Checkpoint} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract PointTokenFacet is Modifiers {
    /*//////////////////////////////////////////////////////////////
                               ERC20
    //////////////////////////////////////////////////////////////*/
    function name() public view returns (string memory) {
        return s.tokenName;
    }

    function symbol() public view returns (string memory) {
        return s.tokenSymbol;
    }

    function decimals() public view returns (uint8) {
        return s.tokenDecimals;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        return LibPointToken.approve(spender, amount);
    }

    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        return LibPointToken.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public whenNotPaused returns (bool) {
        return LibPointToken.transferFrom(from, to, amount);
    }

    function totalSupply() external view returns (uint256) {
        return s.tokenTotalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return s.tokenBalanceOf[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return s.tokenAllowance[owner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        LibPointToken.permit(owner, spender, value, deadline, _v, _r, _s);
    }

    function nonces(address owner) external view returns (uint256) {
        return s.tokenNonces[owner];
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LibPointToken.DOMAIN_SEPARATOR();
    }

    // Votes

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) public view returns (Checkpoint memory) {
        return s.token_checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view returns (uint32) {
        return SafeCast.toUint32(s.token_checkpoints[account].length);
    }

    /**
     * @dev Get the address `account` is currently delegating to.
     */
    function delegates(address account) external view returns (address) {
        return s.tokenDelegates[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(address account) external view returns (uint256) {
        uint256 pos = s.token_checkpoints[account].length;
        return pos == 0 ? 0 : s.token_checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `blockNumber`.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(s.token_checkpoints[account], blockNumber);
    }

    /**
     * @dev Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances.
     * It is but NOT the sum of all the delegated votes!
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(s.token_totalSupplyCheckpoints, blockNumber);
    }

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        //
        // During the loop, the index of the wanted checkpoint remains in the range [low-1, high).
        // With each iteration, either `low` or `high` is moved towards the middle of the range to maintain the invariant.
        // - If the middle checkpoint is after `blockNumber`, we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`, we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the right checkpoint at the index high-1, if not
        // out of bounds (in which case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for `blockNumber`, we end up with an index that is
        // past the end of the array, so we technically don't find a checkpoint after `blockNumber`, but it works out
        // the same.
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : ckpts[high - 1].votes;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) external {
        LibPointToken.delegate(delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        LibPointToken.delegateBySig(delegatee, nonce, expiry, _v, _r, _s);
    }
}
