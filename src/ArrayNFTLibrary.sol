// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {TimeSlotLibrary} from "./TimeSlotSystemLibrary.sol";

library ArrayNFTLibrary {

    using ArrayNFTLibrary for TheFedz;
    using TimeSlotLibrary for uint256[];

    function toArray(TheFedz self) internal view returns (uint256[] memory) {
        return _toArray(self);
    }

    function toArrayWithShuffle(TheFedz self, uint256 random) internal view returns (uint256[] memory) {
        uint256[] memory array = _toArray(self);
        array.shuffle(random);
        return array;
    }

    function _toArray(TheFedz self) internal view returns (uint256[] memory) {
        uint256 totalSlots = self.totalSupply();
        uint256[] memory slots = new uint256[](totalSlots);
        for (uint256 i = 0; i < totalSlots; i++) {
            slots[i] = self.tokenByIndex(i);
        }
        return slots;
    }
}
