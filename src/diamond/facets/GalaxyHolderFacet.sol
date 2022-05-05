// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {IEcliptic} from "../../common/interfaces/IUrbit.sol";
import {LibUrbit} from "../libraries/LibUrbit.sol";

contract GalaxyHolderFacet is Modifiers, IERC721Receiver {
    function setManagementProxy(uint32 _point, address _manager) external onlyGovernanceOrOwnerOrMultisigOrManager {
        LibUrbit.setManagementProxy(_point, _manager);
    }

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) external onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.setSpawnProxy(_prefix, _spawnProxy);
    }

    function setVotingProxy(uint8 _galaxy, address _voter) external onlyGovernanceOrOwnerOrMultisig {
        LibUrbit.setVotingProxy(_galaxy, _voter);
    }

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external onlyGovernance {
        LibUrbit.castDocumentVote(_galaxy, _proposal, _vote);
    }

    function castUpgradeVote(
        uint8 _galaxy,
        address _proposal,
        bool _vote
    ) external onlyGovernance {
        LibUrbit.castUpgradeVote(_galaxy, _proposal, _vote);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

}
