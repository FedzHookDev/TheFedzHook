// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";
import {console} from "forge-std/console.sol";

library InfinteRandomLibrary {

    // struct RandomGenerator {
        // uint256 seed;
    //     uint256 counter;
    // }

    using InfinteRandomLibrary for bytes32;

    // function init(RandomGenerator storage self, bytes32 seed) internal {
    //     self.seed = uint256(seed);
    //     self.counter = 0;
    // }

    function gen(bytes32 self, uint256 nonce) internal returns (uint256 random) {
        random = uint256(keccak256(abi.encodePacked(self, nonce)));
    }

    // function next(RandomGenerator storage self) internal returns (uint256 random) {
    //     // console.logUint(self.counter);
    //     // console.logBytes32(self.seed);
    //     random = uint256(keccak256(abi.encodePacked(self.seed, self.counter++)));
    // }

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
