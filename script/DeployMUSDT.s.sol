// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./mocks/mUSDT.sol";

contract DeployMockUSDT is Script {
    function run() external {
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the MockUNI contract
        MockUSDT mockUSDT = new MockUSDT();

        // Log the address of the deployed contract
        console.log("MockUSDT deployed to:", address(mockUSDT));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
