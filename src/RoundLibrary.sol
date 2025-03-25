// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {TimeSlotLibrary} from "./TimeSlotSystemLibrary.sol";

library RoundLibrary {

    struct Round {
        uint256 number;
        uint256 startsAt;
        uint256 slotDuration;
        uint256[] slots; // turnOrder
    }

    using RoundLibrary for Round;
    using TimeSlotLibrary for uint256[];

    function isRunning(Round storage self) public view returns (bool) {
        return self.startsAt > 0 && block.timestamp >= self.startsAt;
    }

    function currentValue(Round memory self) public view returns (uint256) {
        return self.slots[slotByTimestamp(self, block.timestamp)];
    }

    function currentSlot(Round memory self) public view returns (uint256) {
        return slotByTimestamp(self, block.timestamp);
    }

    function valueByTimestamp(Round memory self, uint256 timestamp) public pure returns (uint256) {
        uint256 slot = slotByTimestamp(self, timestamp);
        if (self.slots.length <= slot) {
            return 0;
        }
        return self.slots[slotByTimestamp(self, timestamp)];
    }

    function slotByTimestamp(Round memory self, uint256 timestamp) public pure returns (uint256) {
        if (self.slotDuration == 0) {
            return 0;
        }
        return ((timestamp - self.startsAt) / self.slotDuration) % self.slots.length;
    }

    function endsInOrLaterThen(Round storage self) public view returns (uint256) {
        uint256 slotDuration = self.slotDuration;
        uint256 slotsLeft = self.slots.length - currentSlot(self);
        return (block.timestamp - (block.timestamp % slotDuration)) + slotsLeft * slotDuration;
    }

    function init(Round storage self, uint256[] memory turnOrder, uint256 startsAt, uint256 slotDuration) internal {
        self.startsAt = startsAt;
        self.slotDuration = slotDuration;
        self.slots = turnOrder;
        self.number = 1;
    }

    function nextRound(Round storage self, uint256[] memory turnOrder) internal view returns (Round memory next) {
        next.startsAt = endsInOrLaterThen(self);
        next.slotDuration = self.slotDuration;
        next.number = self.number+1;
        next.slots = turnOrder;
    }
}
