// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/TimeSlotSystem.sol";
import "../src/MockERC721.sol";

contract DeployTimeSlotSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = 0x27E20BD50106e3Fbc50A230bd5dC02D7793c7D84;
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockERC721
        MockERC721 mockNFT = new MockERC721("Fedz Mock NFT" , "Fedz Mock NFT", owner, 'https://fedzfrontend-loris-epfl-loris-epfls-projects.vercel.app/NftPictures/nft_');

        // Set up parameters for TimeSlotSystem
        uint256 slotDuration = 1 hours;
        uint256 roundDuration = 24 hours;

        // Deploy TimeSlotSystem
        TimeSlotSystem timeSlotSystem = new TimeSlotSystem(
            slotDuration,
            roundDuration,
            owner,
            address(mockNFT)
        );

        console.log("MockERC721 deployed at:", address(mockNFT));
        console.log("TimeSlotSystem deployed at:", address(timeSlotSystem));

        vm.stopBroadcast();
    }
}
