// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, AskStatus, Modifiers, Ask} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract GalaxyPartyFacet is Modifiers {
    event AskCreated(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);
    event AskCanceled(uint16 askId);
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
        require(s.urbit.ecliptic.ownerOf(uint256(_point)) == LibMeta.msgSender(), "caller must own galaxy");
        require(_ethAmount > 0 || _pointAmount > 0, "eth amount and/or point amount must be greater than 0");
        s.galaxyParty.askIds++;
        s.galaxyParty.asks[s.galaxyParty.askIds] = Ask(LibMeta.msgSender(), _ethAmount, _pointAmount, 0, _point, AskStatus.CREATED);
        emit AskCreated(s.galaxyParty.askIds, LibMeta.msgSender(), _point, _ethAmount, _pointAmount);
    }

    function cancelAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        address sender = LibMeta.msgSender();
        require(
            LibDiamond.isContractOwner() ||
                sender == s.governance.governance ||
                sender == s.governance.multisig ||
                sender == s.galaxyParty.asks[_askId].owner,
            "only ask creator or governance"
        );
        require(
            s.galaxyParty.asks[_askId].status == AskStatus.CREATED || s.galaxyParty.asks[_askId].status == AskStatus.APPROVED,
            "ask must be created or approved"
        );
        s.galaxyParty.asks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint16 _askId) public onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.asks[_askId].status == AskStatus.CREATED, "ask must be in created state");
        require(
            s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.NONE ||
                s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.CANCELED ||
                s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.ENDED,
            "there is already an active ask."
        );
        require(
            s.galaxyParty.asks[_askId].owner == s.urbit.ecliptic.ownerOf(uint256(s.galaxyParty.asks[_askId].point)),
            "ask creator is no longer owner"
        );
        s.galaxyParty.asks[_askId].status = AskStatus.APPROVED;
        s.galaxyParty.lastApprovedAskId = _askId;
    }

    function contribute(uint16 _askId) public payable {
        LibUrbit.updateEcliptic(s);
        uint256 _amount = msg.value;
        require(_amount > 0, "must contribute ETH");
        require(
            s.galaxyParty.asks[_askId].status == AskStatus.APPROVED && s.galaxyParty.lastApprovedAskId == _askId,
            "ask must be in approved state"
        );
        require(
            s.galaxyParty.asks[_askId].owner == s.urbit.ecliptic.ownerOf(uint256(s.galaxyParty.asks[_askId].point)),
            "ask creator does not own galaxy"
        );
        uint256 _remaining = s.galaxyParty.asks[_askId].amount - s.galaxyParty.asks[_askId].totalContributedToParty;
        require(_remaining >= _amount, "msg.value is greater than remaining amount");
        address _contributor = LibMeta.msgSender();
        s.galaxyParty.totalContributed[_askId][_contributor] += _amount;
        s.galaxyParty.asks[_askId].totalContributedToParty += _amount;
        emit Contributed(_contributor, _askId, _amount, s.galaxyParty.asks[_askId].amount - s.galaxyParty.asks[_askId].totalContributedToParty);
    }

    function settleAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.asks[_askId].status == AskStatus.APPROVED, "ask status must be APPROVED");
        uint256 ethRaised = s.galaxyParty.asks[_askId].totalContributedToParty;
        require(ethRaised == s.galaxyParty.asks[_askId].amount, "total contributed must equal asking price");
        s.galaxyParty.asks[_askId].status = AskStatus.ENDED;

        s.urbit.ecliptic.safeTransferFrom(s.galaxyParty.asks[_askId].owner, address(this), uint256(s.galaxyParty.asks[_askId].point));

        uint256 pointValuation = ethRaised * s.galaxyParty.TOKEN_SCALE + s.galaxyParty.asks[_askId].pointAmount;
        uint256 treasuryPointInflation = (pointValuation * s.galaxyParty.TREASURY_POINT_INFLATION_BPS) / 10_000;
        LibPointToken.mint(s.governance.governance, treasuryPointInflation);

        if (ethRaised > 0) {
            uint256 treasuryEthFee = (ethRaised * s.galaxyParty.TREASURY_ETH_FEE_BPS) / 10_000;
            (bool feeSuccess, ) = s.governance.governance.call{value: treasuryEthFee}("");
            if (!feeSuccess) {
                emit ETHTransferFailed(s.governance.governance, treasuryEthFee);
            }
            ethRaised -= treasuryEthFee;
        }

        (bool success, ) = s.galaxyParty.asks[_askId].owner.call{value: ethRaised}("");
        require(success, "wallet failed to receive");
        LibPointToken.mint(s.galaxyParty.asks[_askId].owner, s.galaxyParty.asks[_askId].pointAmount);

        emit AskSettled(
            _askId,
            s.galaxyParty.asks[_askId].owner,
            s.galaxyParty.asks[_askId].point,
            ethRaised,
            s.galaxyParty.asks[_askId].pointAmount
        );
    }

    function claim(uint16 _askId) public {
        require(s.galaxyParty.asks[_askId].status == AskStatus.ENDED || s.galaxyParty.asks[_askId].status == AskStatus.CANCELED);
        address sender = LibMeta.msgSender();
        uint256 amount = s.galaxyParty.totalContributed[_askId][LibMeta.msgSender()];
        require(amount > 0);
        require(!s.galaxyParty.claimed[_askId][sender]);
        s.galaxyParty.claimed[_askId][sender] = true;
        if (s.galaxyParty.asks[_askId].status == AskStatus.ENDED) {
            LibPointToken.mint(sender, amount * s.galaxyParty.TOKEN_SCALE);
            emit Claimed(sender, amount * s.galaxyParty.TOKEN_SCALE, 0);
        } else if (s.galaxyParty.asks[_askId].status == AskStatus.CANCELED) {
            (bool success, ) = sender.call{value: amount}("");
            if (!success) {
                emit ETHTransferFailed(sender, amount);
            } else {
                emit Claimed(sender, 0, amount);
            }
        }
    }
}
