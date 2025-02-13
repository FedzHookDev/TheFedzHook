// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";
import {console} from "forge-std/console.sol";

contract RoundRobinTimeSlotSystem is ITimeSlotSystem, Ownable {

    uint256 public startsAt;
    uint256 public slotDuration;
    TheFedz public nftContract;

    constructor(address _owner, address _nftContract) Ownable(_owner) {
        nftContract = TheFedz(_nftContract);
    }

    function restart(uint256 _slotDuration, uint256 _startsAt) external onlyOwner {
        slotDuration = _slotDuration;
        startsAt = _startsAt;
    }

    function getCurrentPlayer() public view returns (address) {
        if (startsAt == 0 || block.timestamp < startsAt) {
            return address(0);
        }
        uint256 totalTurns = nftContract.totalSupply();
        if (totalTurns == 0) {
            return address(0);
        }
        uint256 currentSlot = ((block.timestamp - startsAt) / slotDuration) % totalTurns;
        return nftContract.ownerOf(currentSlot);
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = TheFedz(_nftContract);
    }
}
