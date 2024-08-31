// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./mocks/mFUSD.sol";

contract DeployMockFUSD is Script {
    function run() external {
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MockUNI contract
        MockFUSD mockFUSD = new MockFUSD();

        // Log the address of the deployed contract
        console.log("MockFUSD deployed to:", address(mockFUSD));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
