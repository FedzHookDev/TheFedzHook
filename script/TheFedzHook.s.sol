// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {FedzHook} from "../src/FedzHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract TheFedzHookScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant SEPOLIA_POOLMANAGER = address(0xc021A7Deb4a939fd7E661a0669faB5ac7Ba2D5d6); //sepolia pool manager deployed to GOERLI
    address owner = 0x27E20BD50106e3Fbc50A230bd5dC02D7793c7D84;
    address MOCK_USDT = address(0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f); // Mock USDT address
    address MOCK_FUSD = address(0xc7c06a77b481869ecc57E5432D03c3661406424D); // Mock USDC address
    uint256 depegThreshold = 281474976710656; //0.9 USDT per FUSD in Q64.96 format
    address turnSystem = address(0); // TurnBasedSystem address




    function setUp() public {}

    function run() public {
         // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // hook contracts must have specific flags encoded in the address
       uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(FedzHook).creationCode, abi.encode(owner,address(SEPOLIA_POOLMANAGER),owner,MOCK_USDT,MOCK_FUSD,depegThreshold));

        // Deploy the hook using CREATE2
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        FedzHook TheFedzHook = new FedzHook{salt: salt}(owner, IPoolManager(address(SEPOLIA_POOLMANAGER)),owner,MOCK_USDT,MOCK_FUSD,depegThreshold, turnSystem);
        require(address(TheFedzHook) == hookAddress, "FedzHookScript: hook address mismatch");
        // Log the address of the deployed contract
        console.log("Hook deployed to:", address(TheFedzHook));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
