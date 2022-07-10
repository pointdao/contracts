// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, AskStatus, Modifiers, Ask} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract GalaxyPartyFacet is Modifiers {
    event AskCreated(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event AskPriceUpdated(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event AskCanceled(uint16 askId);
    event AskApproved(uint16 askId);
    event Claimed(address indexed contributor, uint256 tokenAmount, uint256 ethAmount);
    event Contributed(address indexed contributor, uint16 askId, uint256 amount, uint256 remainingUnallocatedEth);
    event AskSettled(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event ETHTransferFailed(address intended, uint256 amount);

    function createAsk(
        uint8 _point,
        uint256 _ethAmount,
        uint256 _pointAmount
    ) public {
        LibUrbit.updateEcliptic(s);
        require(s.ecliptic.ownerOf(uint256(_point)) == LibMeta.msgSender(), "caller must own galaxy");
        require(_ethAmount > 0 || _pointAmount > 0, "eth amount and/or point amount must be greater than 0");
        s.galaxyPartyAskIds++;
        s.galaxyPartyAsks[s.galaxyPartyAskIds] = Ask(LibMeta.msgSender(), _ethAmount, _pointAmount, 0, _point, AskStatus.CREATED);
        emit AskCreated(s.galaxyPartyAskIds, LibMeta.msgSender(), _point, _ethAmount, _pointAmount);
    }

    function updateAskPrice(
        uint16 _askId,
        uint256 _ethAmount,
        uint256 _pointAmount
    ) public {
        require(_ethAmount > 0 || _pointAmount > 0, "eth amount and/or point amount must be greater than 0");
        require(s.galaxyPartyAsks[_askId].status == AskStatus.CREATED, "ask must be in created state");
        require(LibMeta.msgSender() == s.galaxyPartyAsks[_askId].owner, "only ask creator");

        s.galaxyPartyAsks[_askId].amount = _ethAmount;
        s.galaxyPartyAsks[_askId].pointAmount = _pointAmount;
        emit AskPriceUpdated(_askId, s.galaxyPartyAsks[_askId].owner, s.galaxyPartyAsks[_askId].point, _ethAmount, _pointAmount);
    }

    function cancelAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        address sender = LibMeta.msgSender();
        require(
            LibDiamond.isContractOwner() || sender == s.governance || sender == s.multisig || sender == s.galaxyPartyAsks[_askId].owner,
            "only ask creator or governance"
        );
        require(
            s.galaxyPartyAsks[_askId].status == AskStatus.CREATED || s.galaxyPartyAsks[_askId].status == AskStatus.APPROVED,
            "ask must be created or approved"
        );
        s.galaxyPartyAsks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint16 _askId) public onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyPartyAsks[_askId].status == AskStatus.CREATED, "ask must be in created state");
        AskStatus lastApprovedAskStatus = s.galaxyPartyAsks[s.galaxyPartyLastApprovedAskId].status;
        require(
            lastApprovedAskStatus == AskStatus.NONE || lastApprovedAskStatus == AskStatus.CANCELED || lastApprovedAskStatus == AskStatus.ENDED,
            "there is already an active ask."
        );
        require(s.galaxyPartyAsks[_askId].owner == s.ecliptic.ownerOf(uint256(s.galaxyPartyAsks[_askId].point)), "ask creator is no longer owner");
        s.galaxyPartyAsks[_askId].status = AskStatus.APPROVED;
        s.galaxyPartyLastApprovedAskId = _askId;
        emit AskApproved(_askId);
    }

    function contribute(uint16 _askId) public payable {
        LibUrbit.updateEcliptic(s);
        uint256 _amount = msg.value;
        require(_amount > 0, "must contribute ETH");
        require(s.galaxyPartyAsks[_askId].status == AskStatus.APPROVED && s.galaxyPartyLastApprovedAskId == _askId, "ask must be in approved state");
        require(s.galaxyPartyAsks[_askId].owner == s.ecliptic.ownerOf(uint256(s.galaxyPartyAsks[_askId].point)), "ask creator does not own galaxy");
        uint256 _remaining = s.galaxyPartyAsks[_askId].amount - s.galaxyPartyAsks[_askId].totalContributedToParty;
        require(_remaining >= _amount, "msg.value is greater than remaining amount");
        address _contributor = LibMeta.msgSender();
        s.galaxyPartyTotalContributed[_askId][_contributor] += _amount;
        s.galaxyPartyAsks[_askId].totalContributedToParty += _amount;
        emit Contributed(_contributor, _askId, _amount, s.galaxyPartyAsks[_askId].amount - s.galaxyPartyAsks[_askId].totalContributedToParty);
    }

    function settleAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyPartyAsks[_askId].status == AskStatus.APPROVED, "ask status must be APPROVED");
        uint256 ethRaised = s.galaxyPartyAsks[_askId].totalContributedToParty;
        require(ethRaised == s.galaxyPartyAsks[_askId].amount, "total contributed must equal asking price");
        s.galaxyPartyAsks[_askId].status = AskStatus.ENDED;

        s.ecliptic.safeTransferFrom(s.galaxyPartyAsks[_askId].owner, address(this), uint256(s.galaxyPartyAsks[_askId].point));

        uint256 pointValuation = ethRaised * s.galaxyParty_TOKEN_SCALE + s.galaxyPartyAsks[_askId].pointAmount;
        uint256 treasuryPointInflation = (pointValuation * s.galaxyParty_TREASURY_POINT_INFLATION_BPS) / 10_000;
        LibPointToken.mint(s.governance, treasuryPointInflation);

        if (ethRaised > 0) {
            uint256 treasuryEthFee = (ethRaised * s.galaxyParty_TREASURY_ETH_FEE_BPS) / 10_000;
            (bool feeSuccess, ) = s.governance.call{value: treasuryEthFee}("");
            if (!feeSuccess) {
                emit ETHTransferFailed(s.governance, treasuryEthFee);
            }
            ethRaised -= treasuryEthFee;
        }

        (bool success, ) = s.galaxyPartyAsks[_askId].owner.call{value: ethRaised}("");
        require(success, "wallet failed to receive");
        LibPointToken.mint(s.galaxyPartyAsks[_askId].owner, s.galaxyPartyAsks[_askId].pointAmount);

        emit AskSettled(_askId, s.galaxyPartyAsks[_askId].owner, s.galaxyPartyAsks[_askId].point, ethRaised, s.galaxyPartyAsks[_askId].pointAmount);
    }

    function claim(uint16 _askId) public {
        require(s.galaxyPartyAsks[_askId].status == AskStatus.ENDED || s.galaxyPartyAsks[_askId].status == AskStatus.CANCELED);
        address sender = LibMeta.msgSender();
        uint256 amount = s.galaxyPartyTotalContributed[_askId][LibMeta.msgSender()];
        require(amount > 0);
        require(!s.galaxyPartyClaimed[_askId][sender]);
        s.galaxyPartyClaimed[_askId][sender] = true;
        if (s.galaxyPartyAsks[_askId].status == AskStatus.ENDED) {
            LibPointToken.mint(sender, amount * s.galaxyParty_TOKEN_SCALE);
            emit Claimed(sender, amount * s.galaxyParty_TOKEN_SCALE, 0);
        } else if (s.galaxyPartyAsks[_askId].status == AskStatus.CANCELED) {
            (bool success, ) = sender.call{value: amount}("");
            if (!success) {
                emit ETHTransferFailed(sender, amount);
            } else {
                emit Claimed(sender, 0, amount);
            }
        }
    }
}
