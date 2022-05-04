// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {AppStorage, SwapStatus, AskStatus, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";
import {LibPointToken} from "../libraries/LibPointToken.sol";

contract GalaxyPartyFacet is Modifiers {
    AppStorage internal s;

    event AskCreated(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    event AskCanceled(uint16 askId);

    event SwapInitiated(uint16 swapId, address owner, uint8 point);

    event SwapCanceled(uint16 swapId);

    event SwapCompleted(uint16 swapId, address owner, uint8 point);

    event Contributed(address indexed contributor, uint16 askId, uint256 amount, uint256 remainingUnallocatedEth);

    event AskSettled(uint16 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    event ETHTransferFailed(address intended, uint256 amount, address treasury);

    function initiateGalaxySwap(uint8 _point) public {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.ecliptic.ownerOf(uint256(_point)) == LibMeta.msgSender(), "caller must own galaxy");
        s.galaxyParty.swapIds++;
        s.galaxyParty.swaps[s.galaxyParty.swapIds] = Swap(LibMeta.msgSender(), _point, block.number, SwapStatus.INITIATED);
        emit SwapInitiated(s.galaxyParty.swapIds, LibMeta.msgSender(), _point);
    }

    function completeGalaxySwap(uint16 _swapId) public {
        address _sender = LibMeta.msgSender();
        uint8 _point = s.galaxyParty.swaps[_swapId].point;
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.swaps[_swapId].status == SwapStatus.INITIATED, "swap must exist and be in INITIATED state");
        require(s.ecliptic.ownerOf(uint256(_point)) == _sender, "caller must own galaxy");
        require(s.galaxyParty.swaps[_swapId].owner == _sender, "caller must be swap creator");
        require(block.number > s.galaxyParty.swaps[_swapId].initiatedBlock, "caller must complete swap in a later block");
        s.urbit.ecliptic.safeTransferFrom(_sender, address(this), uint256(_point));
        LibPointToken.mint(_sender, s.token.PARTY_AMOUNT);
        s.galaxyParty.swaps[_swapId].status = SwapStatus.COMPLETE;
        emit SwapCompleted(_swapId, _sender, _point);
    }

    function cancelGalaxySwap(uint16 _swapId) public {
        LibUrbit.updateEcliptic(s);
        uint8 _point = s.galaxyParty.swaps[_swapId].point;
        uint8 _sender = LibMeta.msgSender();
        require(s.galaxyParty.swaps[_swapId].status == SwapStatus.INITIATED, "swap must exist and be in INITIATED state");
        require(s.galaxyParty.swaps[_swapId].owner == _sender, "caller must be swap creator");
        s.galaxyParty.swaps[_swapId].status = SwapStatus.CANCELED;
        emit SwapCanceled(_swapId);
    }

    function createAsk(
        uint8 _point,
        uint256 _ethPerPoint, // eth value of 1*10**18 POINT, must be in 0.001 ETH increments
        uint256 _pointAmount // POINT for seller, must be in 1 POINT increments
    ) public {
        LibUrbit.updateEcliptic(s);
        require(s.urbit.ecliptic.ownerOf(uint256(_point)) == _msgSender(), "caller must own galaxy");
        require(_pointAmount < s.token.PARTY_AMOUNT, "_pointAmount must be less than total PARTY_AMOUNT");
        require(_pointAmount % s.galaxyParty.SELLER_POINT_INCREMENT == 0, "seller can only ask for whole number of POINT");
        require(_ethPerPoint > 0, "eth per point must be greater than 0");
        require(_ethPerPoint % s.SELLER_ETH_PER_POINT_INCREMENT == 0, "eth per point must be in 0.001 ETH increments");

        //TODO: fix rounding / division stuff
        uint256 _amount = ((s.token.PARTY_AMOUNT - _pointAmount) / 10**18) * _ethPerPoint; // amount unallocated ETH

        s.galaxyParty.askIds++;
        asks[s.galaxyParty.askIds] = Ask(LibMeta.msgSender(), _amount, _pointAmount, 0, _point, AskStatus.CREATED);

        emit AskCreated(s.galaxyParty.askIds, LibMeta.msgSender(), _point, _amount, _pointAmount);
    }

    function cancelAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        address sender = LibMeta.msgSender();
        require(
            s.galaxyParty.asks[_askId].status == AskStatus.CREATED || s.galaxyParty.asks[_askId].status == AskStatus.APPROVED,
            "ask must be created or approved"
        );
        require(
            sender == s.governance.governance ||
                sender == s.governance.multisig ||
                sender == s.galaxyParty.asks[_askId].owner ||
                sender == s.urbit.ecliptic.ownerOf(uint256(s.galaxyParty.asks[_askId].point))
        );
        s.galaxyParty.asks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint16 _askId) public onlyGovernance {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.asks[_askId].status == AskStatus.CREATED, "ask must be in created state");
        require(
            s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.NONE ||
                s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.CANCELED ||
                s.galaxyParty.asks[s.galaxyParty.lastApprovedAskId].status == AskStatus.ENDED,
            "there is a previously approved ask that is not canceled/ended."
        );
        require(
            s.galaxyParty.asks[_askId].owner == s.urbit.ecliptic.ownerOf(uint256(s.galaxyParty.asks[_askId].point)),
            "ask creator is no longer owner"
        );
        s.galaxyParty.asks[_askId].status = AskStatus.APPROVED;
        s.galaxyParty.lastApprovedAskId = _askId;
    }

    function contribute(uint16 _askId, uint256 _pointAmount) public payable {
        LibUrbit.updateEcliptic(s);
        // if galaxy owner does not own token anymore, cancel ask and refund current contributor
        require(
            s.galaxyParty.asks[_askId].status == AskStatus.APPROVED && s.galaxyParty.lastApprovedAskId == _askId,
            "ask must be in approved state"
        );
        require(
            s.galaxyParty.asks[_askId].owner == s.urbit.ecliptic.ownerOf(uint256(s.galaxyParty.asks[_askId].point)),
            "ask creator does not own galaxy"
        );
        require(
            _pointAmount > 0 && _pointAmount % s.galaxyParty.CONTRIBUTOR_POINT_INCREMENT == 0,
            "point amount must be greater than 0 and in increments of 0.001"
        );
        uint256 _ethPerPoint = s.galaxyParty.asks[_askId].amount / (s.token.PARTY_AMOUNT - s.galaxyParty.asks[_askId].pointAmount);
        uint256 _amount = msg.value;
        require(_amount == _pointAmount * _ethPerPoint, "msg.value needs to match pointAmount");
        require(_amount <= s.galaxyParty.asks[_askId].amount - s.galaxyParty.asks[_askId].totalContributedToParty, "cannot exceed asking price");
        address _contributor = LibMeta.msgSender();
        // add to contributor's total contribution
        s.galaxyParty.totalContributed[_askId][_contributor] = s.galaxyParty.totalContributed[_askId][_contributor] + _amount;
        // add to party's total contribution & emit event
        s.galaxyParty.asks[_askId].totalContributedToParty = s.galaxyParty.asks[_askId].totalContributedToParty + _amount;
        emit Contributed(_contributor, _askId, _amount, s.galaxyParty.asks[_askId].amount - s.galaxyParty.asks[_askId].totalContributedToParty);
        if (s.galaxyParty.asks[_askId].totalContributedToParty == s.galaxyParty.asks[_askId].amount) {
            settleAsk(_askId);
        }
    }

    function settleAsk(uint16 _askId) public {
        LibUrbit.updateEcliptic(s);
        require(s.galaxyParty.asks[_askId].status == AskStatus.APPROVED);
        require(s.galaxyParty.asks[_askId].amount == s.galaxyParty.asks[_askId].totalContributedToParty);
        s.galaxyParty.asks[_askId].status = AskStatus.ENDED;
        s.urbit.ecliptic.safeTransferFrom(s.galaxyParty.asks[_askId].owner, address(this), uint256(s.galaxyParty.asks[_askId].point));
        (bool success, ) = s.galaxyParty.asks[_askId].owner.call{value: s.galaxyParty.asks[_askId].amount}("");
        require(success, "wallet failed to receive");
        LibPointToken.mint(s.galaxyParty.asks[_askId].owner, s.galaxyParty.asks[_askId].pointAmount);
        emit AskSettled(
            _askId,
            s.galaxyParty.asks[_askId].owner,
            s.galaxyParty.asks[_askId].point,
            s.galaxyParty.asks[_askId].amount,
            s.galaxyParty.asks[_askId].pointAmount
        );
    }

    function claim(uint16 _askId) public {
        require(s.galaxyParty.asks[_askId].status == AskStatus.ENDED || s.galaxyParty.asks[_askId].status == AskStatus.CANCELED);
        require(s.galaxyParty.totalContributed[_askId][LibMeta.msgSender()] > 0);
        require(!s.galaxyParty.claimed[_askId][LibMeta.msgSender()]);
        s.galaxyParty.claimed[_askId][LibMeta.msgSender()] = true;
        if (s.galaxyParty.asks[_askId].status == AskStatus.ENDED) {
            uint256 _pointAmount = (s.galaxyParty.totalContributed[_askId][LibMeta.msgSender()] / s.galaxyParty.asks[_askId].amount) *
                (s.galaxyParty.PARTY_AMOUNT - s.galaxyParty.asks[_askId].pointAmount);
            LibPointToken.mint(LibMeta.msgSender(), _pointAmount);
        } else if (s.galaxyParty.asks[_askId].status == AskStatus.CANCELED) {
            uint256 _ethAmount = s.galaxyParty.totalContributed[_askId][LibMeta.msgSender()];
            (bool success, ) = LibMeta.msgSender().call{value: _ethAmount}("");
            if (!success) {
                emit ETHTransferFailed(LibMeta.msgSender(), _ethAmount, treasury);
            }
        }
    }
}
