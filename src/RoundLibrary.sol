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

    function currentSlot(Round memory self) public view returns (uint256) {
        return slotByTimestamp(self, block.timestamp);
    }

    function currentSlotValue(Round memory self) public view returns (uint256) {
        return self.slots[slotByTimestamp(self, block.timestamp)];
    }

    function slotByTimestamp(Round memory self, uint256 timestamp) public view returns (uint256) {
        return ((timestamp - self.startsAt) / self.slotDuration) % self.slots.length;
    }

    function endsInOrLaterThen(Round storage self) public view returns (uint256) {
        uint256 cur = currentSlot(self);
        uint256 slotsLeft = self.slots.length - cur;
        return block.timestamp + slotsLeft * self.slotDuration;
    }

    function init(Round storage self, uint256[] memory turnOrder, uint256 startsAt, uint256 slotDuration) internal {
        self.startsAt = startsAt;
        self.slotDuration = slotDuration;
        self.slots = turnOrder;
        self.number = 1;
    }

    function nextRound(Round storage self, uint256[] memory turnOrder) internal returns (Round memory nextRound) {
        nextRound.startsAt = endsInOrLaterThen(self);
        nextRound.slotDuration = self.slotDuration;
        nextRound.number = self.number+1;
        nextRound.slots = turnOrder;
    }
}
