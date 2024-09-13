// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MockERC721.sol";

contract DeployMockERC721 is Script {
    function run() external {
        
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = 0x27E20BD50106e3Fbc50A230bd5dC02D7793c7D84;

        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MockERC721 contract
        MockERC721 mockNFT = new MockERC721(
            "MockNFT",                  // name
            "MNFT",                     // symbol
            owner,// initialOwner (the deployer)
            "https://example.com/nft/"  // baseTokenURI
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log the address of the deployed contract
        console.log("MockERC721 deployed at:", address(mockNFT));
    }
}
