// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LibDiamond} from "./LibDiamond.sol";
import {LibAppStorage, AppStorage, Modifiers, Checkpoint} from "./LibAppStorage.sol";
import {LibMeta} from "./LibMeta.sol";

library LibPointToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function pause() internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.tokenPaused = true;
        emit Paused(LibMeta.msgSender());
    }

    function unpause() internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.tokenPaused = false;
        emit Unpaused(LibMeta.msgSender());
    }

    function mint(address to, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.tokenTotalSupply += amount;

        unchecked {
            s.tokenBalanceOf[to] += amount;
        }

        require(s.tokenTotalSupply <= s.tokenMaxSupply, "ERC20Votes: total supply risks overflowing votes");

        _writeCheckpoint(s.token_totalSupplyCheckpoints, _add, amount);

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.tokenBalanceOf[from] -= amount;

        unchecked {
            s.tokenTotalSupply -= amount;
        }

        _writeCheckpoint(s.token_totalSupplyCheckpoints, _subtract, amount);

        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.tokenAllowance[LibMeta.msgSender()][spender] = amount;

        emit Approval(LibMeta.msgSender(), spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.tokenBalanceOf[LibMeta.msgSender()] -= amount;

        unchecked {
            s.tokenBalanceOf[to] += amount;
        }

        emit Transfer(LibMeta.msgSender(), to, amount);

        _moveVotingPower(s.token_delegates[LibMeta.msgSender()], s.token_delegates[to], amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 allowed = s.tokenAllowance[from][LibMeta.msgSender()];

        if (allowed != type(uint256).max) s.tokenAllowance[from][LibMeta.msgSender()] = allowed - amount;

        s.tokenBalanceOf[from] -= amount;

        unchecked {
            s.tokenBalanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        _moveVotingPower(s.token_delegates[from], s.token_delegates[to], amount);

        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 nonce = s.tokenNonces[owner]++;

        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                value,
                                nonce,
                                deadline
                            )
                        )
                    )
                ),
                _v,
                _r,
                _s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            s.tokenAllowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return block.chainid == s.INITIAL_CHAIN_ID ? s.INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(s.tokenName)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _useNonce(address owner) internal returns (uint256 current) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        current = s.tokenNonces[owner];
        s.tokenNonces[owner]++;
    }

    function delegate(address delegatee) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address currentDelegate = s.token_delegates[LibMeta.msgSender()];
        uint256 delegatorBalance = s.tokenBalanceOf[LibMeta.msgSender()];
        s.token_delegates[LibMeta.msgSender()] = delegatee;

        emit DelegateChanged(LibMeta.msgSender(), currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(block.timestamp <= expiry, "ERC20Votes: signature expired");
        address signer = ECDSA.recover(
            ECDSA.toTypedDataHash(DOMAIN_SEPARATOR(), keccak256(abi.encode(s.token_DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            _v,
            _r,
            _s
        );
        require(nonce == _useNonce(signer), "ERC20Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address currentDelegate = s.token_delegates[delegator];
        uint256 delegatorBalance = s.tokenBalanceOf[delegator];
        s.token_delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(s.token_checkpoints[src], _subtract, amount);
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(s.token_checkpoints[dst], _add, amount);
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(Checkpoint({fromBlock: SafeCast.toUint32(block.number), votes: SafeCast.toUint224(newWeight)}));
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }
}
