// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC721Holder} from "../../../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

contract MockWallet is ERC721Holder {
    event Received(address sender, uint256 amount, uint256 balance);

    receive() external payable {
        emit Received(msg.sender, msg.value, address(this).balance);
    }
}
