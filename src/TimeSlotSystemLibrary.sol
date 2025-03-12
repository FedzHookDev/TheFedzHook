// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";

library TimeSlotLibrary {

    using TimeSlotLibrary for uint256[];

    function shuffle(uint256[] memory self, uint256 random) internal pure {
        uint256 totalSlots = self.length;
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = random % (i + 1);
            uint256 temp = self[i];
            self[i] = self[j];
            self[j] = temp;
        }
    }

    function shuffle(uint256[] storage self, uint256 random) internal {
        uint256 totalSlots = self.length;
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = random % (i + 1);
            uint256 temp = self[i];
            self[i] = self[j];
            self[j] = temp;
        }
    }
}
