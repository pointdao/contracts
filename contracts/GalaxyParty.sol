/*
 ________  ________  ___  ________   _________        ________  ________  ________                                           
|\   __  \|\   __  \|\  \|\   ___  \|\___   ___\     |\   ___ \|\   __  \|\   __  \                                          
\ \  \|\  \ \  \|\  \ \  \ \  \\ \  \|___ \  \_|     \ \  \_|\ \ \  \|\  \ \  \|\  \                                         
 \ \   ____\ \  \\\  \ \  \ \  \\ \  \   \ \  \       \ \  \ \\ \ \   __  \ \  \\\  \                                        
  \ \  \___|\ \  \\\  \ \  \ \  \\ \  \   \ \  \       \ \  \_\\ \ \  \ \  \ \  \\\  \                                       
   \ \__\    \ \_______\ \__\ \__\\ \__\   \ \__\       \ \_______\ \__\ \__\ \_______\                                      
    \|__|     \|_______|\|__|\|__| \|__|    \|__|        \|_______|\|__|\|__|\|_______|                                      
                                                                                                                             
                                                                                                                             
                                                                                                                             
 ________  ________  ___       ________     ___    ___ ___    ___      ________  ________  ________  _________    ___    ___ 
|\   ____\|\   __  \|\  \     |\   __  \   |\  \  /  /|\  \  /  /|    |\   __  \|\   __  \|\   __  \|\___   ___\ |\  \  /  /|
\ \  \___|\ \  \|\  \ \  \    \ \  \|\  \  \ \  \/  / | \  \/  / /    \ \  \|\  \ \  \|\  \ \  \|\  \|___ \  \_| \ \  \/  / /
 \ \  \  __\ \   __  \ \  \    \ \   __  \  \ \    / / \ \    / /      \ \   ____\ \   __  \ \   _  _\   \ \  \   \ \    / / 
  \ \  \|\  \ \  \ \  \ \  \____\ \  \ \  \  /     \/   \/  /  /        \ \  \___|\ \  \ \  \ \  \\  \|   \ \  \   \/  /  /  
   \ \_______\ \__\ \__\ \_______\ \__\ \__\/  /\   \ __/  / /           \ \__\    \ \__\ \__\ \__\\ _\    \ \__\__/  / /    
    \|_______|\|__|\|__|\|_______|\|__|\|__/__/ /\ __\\___/ /             \|__|     \|__|\|__|\|__|\|__|    \|__|\___/ /     
                                           |__|/ \|__\|___|/                                                    \|___|/      
                                                                                                                             
                                                                                                                                                            ~~                        ~~
Author: James Geary
Credit: adapted from PartyBid by Anna Carroll
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Context} from "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {Counters} from "../lib/openzeppelin-contracts/contracts/utils/Counters.sol";

import {GalaxyLocker} from "./GalaxyLocker.sol";
import {Point} from "./Point.sol";
import {IEcliptic, IOwnable} from "./urbit/IUrbit.sol";

contract GalaxyParty is Context {
    enum AskStatus {
        NONE,
        CREATED,
        APPROVED,
        CANCELED,
        ENDED
    }

    enum SwapStatus {
        NONE,
        INITIATED,
        CANCELED,
        COMPLETE
    }

    struct Ask {
        address owner;
        uint256 amount;
        uint256 pointAmount;
        uint256 totalContributedToParty;
        uint8 point;
        AskStatus status;
    }

    struct Swap {
        address owner;
        uint8 point;
        uint256 initiatedBlock;
        SwapStatus status;
    }

    IOwnable public azimuth;
    IERC721 public ecliptic;
    address public multisig;
    Point public pointToken;
    GalaxyLocker public galaxyLocker;
    address payable public treasury;

    using Counters for Counters.Counter;
    Counters.Counter private askIds;
    Counters.Counter private swapIds;
    uint256 public lastApprovedAskId;

    mapping(uint256 => Ask) asks;
    mapping(uint256 => Swap) swaps;

    // ask id -> address -> total contributed
    mapping(uint256 => mapping(address => uint256)) totalContributed;

    // ask id -> whether user has claimed yet
    mapping(uint256 => mapping(address => bool)) public claimed;

    // example: seller values galaxy at 597 eth and asks for 1 point. so 1 point == 0.597 eth, and 596.403 ETH remain unallocated. contributions must be in 0.001 POINT equivalent increments, so 0.000597 ETH increments in this case.
    uint256 constant POINT_PER_GALAXY = 1000 * (10**18); // 1000 POINT are distributed for each galaxy sale
    uint256 constant SELLER_POINT_INCREMENT = 10**18; // seller can only ask for whole number of POINT and value galaxy in whole number of ETH
    uint256 constant SELLER_ETH_PER_POINT_INCREMENT = 10**15; // seller can only price 1 POINT in 0.001 ETH increments
    uint256 constant CONTRIBUTOR_POINT_INCREMENT = 10**15; // contributions must be valued in 0.001 POINT increments

    event AskCreated(uint256 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    event AskCanceled(uint256 askId);

    event SwapInitiated(uint256 swapId, address owner, uint8 point);

    event SwapCanceled(uint256 swapId);

    event SwapCompleted(uint256 swapId, address owner, uint8 point);

    event Contributed(address indexed contributor, uint256 askId, uint256 amount, uint256 remainingUnallocatedEth);

    event AskSettled(uint256 askId, address owner, uint8 point, uint256 amount, uint256 pointAmount);

    event ETHTransferFailed(address intended, uint256 amount, address treasury);

    constructor(
        address _azimuth,
        address _multisig,
        Point _pointToken,
        GalaxyLocker _galaxyLocker,
        address payable _treasury
    ) {
        azimuth = IOwnable(_azimuth);
        multisig = _multisig;
        pointToken = _pointToken;
        galaxyLocker = _galaxyLocker;
        treasury = _treasury;
        _updateEcliptic();
        askIds.increment();
        swapIds.increment();
    }

    modifier onlyGovernance() {
        require(_msgSender() == treasury || _msgSender() == multisig);
        _;
    }

    function _updateEcliptic() internal {
        ecliptic = IERC721(azimuth.owner());
    }

    function setMultisig(address _multisig) public onlyGovernance {
        multisig = _multisig;
    }

    function setTreasury(address payable _treasury) public onlyGovernance {
        treasury = _treasury;
    }

    function initiateGalaxySwap(uint8 _point) public {
        _updateEcliptic();
        require(ecliptic.ownerOf(uint256(_point)) == _msgSender(), "caller must own galaxy");
        uint256 swapId = swapIds.current();
        swaps[swapId] = Swap(_msgSender(), _point, block.number, SwapStatus.INITIATED);
        swapIds.increment();
        emit SwapInitiated(swapId, _msgSender(), _point);
    }

    function completeGalaxySwap(uint256 _swapId) public {
        _updateEcliptic();
        require(swaps[_swapId].status == SwapStatus.INITIATED, "swap must exist and be in INITIATED state");
        require(ecliptic.ownerOf(uint256(swaps[_swapId].point)) == _msgSender(), "caller must own galaxy");
        require(swaps[_swapId].owner == _msgSender(), "caller must be swap creator");
        require(block.number > swaps[_swapId].initiatedBlock, "caller must complete swap in a later block");
        ecliptic.safeTransferFrom(_msgSender(), address(galaxyLocker), uint256(swaps[_swapId].point));
        pointToken.galaxyMint(_msgSender(), POINT_PER_GALAXY);
        swaps[_swapId].status = SwapStatus.COMPLETE;
        emit SwapCompleted(_swapId, _msgSender(), swaps[_swapId].point);
    }

    function cancelGalaxySwap(uint256 _swapId) public {
        _updateEcliptic();
        require(swaps[_swapId].status == SwapStatus.INITIATED, "swap must exist and be in INITIATED state");
        require(ecliptic.ownerOf(uint256(swaps[_swapId].point)) == _msgSender(), "caller must own galaxy");
        require(swaps[_swapId].owner == _msgSender(), "caller must be swap creator");
        swaps[_swapId].status = SwapStatus.CANCELED;
        emit SwapCanceled(_swapId);
    }

    // galaxy owner lists token for sale
    function createAsk(
        uint8 _point,
        uint256 _ethPerPoint, // eth value of 1*10**18 POINT, must be in 0.001 ETH increments
        uint256 _pointAmount // POINT for seller, must be in 1 POINT increments
    ) public {
        _updateEcliptic();
        require(ecliptic.ownerOf(uint256(_point)) == _msgSender(), "caller must own galaxy");
        require(_pointAmount < POINT_PER_GALAXY, "_pointAmount must be less than POINT_PER_GALAXY");
        require(_pointAmount % SELLER_POINT_INCREMENT == 0, "seller can only ask for whole number of POINT");
        require(_ethPerPoint > 0, "eth per point must be greater than 0");
        require(_ethPerPoint % SELLER_ETH_PER_POINT_INCREMENT == 0, "eth per point must be in 0.001 ETH increments");

        //TODO: fix rounding / division stuff
        uint256 _amount = ((POINT_PER_GALAXY - _pointAmount) / 10**18) * _ethPerPoint; // amount unallocated ETH
        address owner = _msgSender();
        uint256 askId = askIds.current();
        asks[askId] = Ask(owner, _amount, _pointAmount, 0, _point, AskStatus.CREATED);

        askIds.increment();
        emit AskCreated(askId, owner, _point, _amount, _pointAmount);
    }

    function cancelAsk(uint256 _askId) public {
        _updateEcliptic();
        require(asks[_askId].status == AskStatus.CREATED || asks[_askId].status == AskStatus.APPROVED, "ask must be created or approved");
        require(
            _msgSender() == treasury ||
                _msgSender() == multisig ||
                _msgSender() == asks[_askId].owner ||
                _msgSender() == ecliptic.ownerOf(uint256(asks[_askId].point))
        );
        asks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint256 _askId) public onlyGovernance {
        _updateEcliptic();
        require(asks[_askId].status == AskStatus.CREATED, "ask must be in created state");
        require(
            asks[lastApprovedAskId].status == AskStatus.NONE ||
                asks[lastApprovedAskId].status == AskStatus.CANCELED ||
                asks[lastApprovedAskId].status == AskStatus.ENDED,
            "there is a previously approved ask that is not canceled/ended."
        );
        require(asks[_askId].owner == ecliptic.ownerOf(uint256(asks[_askId].point)), "ask creator is no longer owner");
        asks[_askId].status = AskStatus.APPROVED;
        lastApprovedAskId = _askId;
    }

    function contribute(uint256 _askId, uint256 _pointAmount) public payable {
        _updateEcliptic();
        // if galaxy owner does not own token anymore, cancel ask and refund current contributor
        require(asks[_askId].status == AskStatus.APPROVED && lastApprovedAskId == _askId, "ask must be in approved state");
        if (asks[_askId].owner != ecliptic.ownerOf(uint256(asks[_askId].point))) {
            asks[_askId].status = AskStatus.CANCELED;
            (bool success, ) = _msgSender().call{value: msg.value}("");
            if (!success) {
                treasury.call{value: msg.value}("");
                emit ETHTransferFailed(_msgSender(), msg.value, treasury);
            }
            return;
        }
        require(
            _pointAmount > 0 && _pointAmount % CONTRIBUTOR_POINT_INCREMENT == 0,
            "point amount must be greater than 0 and in increments of 0.001"
        );
        uint256 _ethPerPoint = asks[_askId].amount / (POINT_PER_GALAXY - asks[_askId].pointAmount);
        uint256 _amount = msg.value;
        require(_amount == _pointAmount * _ethPerPoint, "msg.value needs to match pointAmount");
        require(_amount <= asks[_askId].amount - asks[_askId].totalContributedToParty, "cannot exceed asking price");
        address _contributor = _msgSender();
        // add to contributor's total contribution
        totalContributed[_askId][_contributor] = totalContributed[_askId][_contributor] + _amount;
        // add to party's total contribution & emit event
        asks[_askId].totalContributedToParty = asks[_askId].totalContributedToParty + _amount;
        emit Contributed(_contributor, _askId, _amount, asks[_askId].amount - asks[_askId].totalContributedToParty);
        if (asks[_askId].totalContributedToParty == asks[_askId].amount) {
            settleAsk(_askId);
        }
    }

    function settleAsk(uint256 _askId) public {
        _updateEcliptic();
        require(asks[_askId].status == AskStatus.APPROVED);
        require(asks[_askId].amount == asks[_askId].totalContributedToParty);
        asks[_askId].status = AskStatus.ENDED;
        ecliptic.safeTransferFrom(asks[_askId].owner, address(galaxyLocker), uint256(asks[_askId].point));
        (bool success, ) = asks[_askId].owner.call{value: asks[_askId].amount}("");
        require(success, "wallet failed to receive");
        pointToken.galaxyMint(asks[_askId].owner, asks[_askId].pointAmount);
        emit AskSettled(_askId, asks[_askId].owner, asks[_askId].point, asks[_askId].amount, asks[_askId].pointAmount);
    }

    function claim(uint256 _askId) public {
        require(asks[_askId].status == AskStatus.ENDED || asks[_askId].status == AskStatus.CANCELED);
        require(totalContributed[_askId][_msgSender()] > 0);
        require(!claimed[_askId][_msgSender()]);
        claimed[_askId][_msgSender()] = true;
        if (asks[_askId].status == AskStatus.ENDED) {
            uint256 _pointAmount = (totalContributed[_askId][_msgSender()] / asks[_askId].amount) * (POINT_PER_GALAXY - asks[_askId].pointAmount);
            pointToken.galaxyMint(_msgSender(), _pointAmount);
        } else if (asks[_askId].status == AskStatus.CANCELED) {
            uint256 _ethAmount = totalContributed[_askId][_msgSender()];
            (bool success, ) = _msgSender().call{value: _ethAmount}("");
            if (!success) {
                treasury.call{value: _ethAmount}("");
                emit ETHTransferFailed(_msgSender(), _ethAmount, treasury);
            }
        }
    }
}
