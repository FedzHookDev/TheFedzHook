// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "@uniswap/v4-core/src/test/PoolDonateTest.sol";
import {FedzHook} from "../src/FedzHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {ShuffleTimeSlotSystem} from "../src/ShuffleTimeSlotSystem.sol";
import {MockERC721} from "../src/MockERC721.sol";

// --rpc-url https://arbitrum.rpc.subquery.network/public
// --etherscan-api-key 6N6Q2DRTUHGIVZ462FXWCX8AW7JPJTZBQ3
// --verify
contract TheFedzHookScript is Script {

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant ARBITRUM_POOLMANAGER = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); //sepolia pool manager deployed to GOERLI
    address owner = 0x833e421145863237e9B372dbA99EcF49C98956fb;
    address MOCK_USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address MOCK_FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address
    address THE_FEDZ_NFT = 0xE073a53a2Ba1709e2c8F481f1D7dbabA1eF611FD;
    uint256 depegThreshold = 281474976710656; //0.9 USDT per FUSD in Q64.96 format
    address timeSlotSystem; 

    function setUp() public {}

    function run() public {
         // Retrieve the private key from the environment variable
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // hook contracts must have specific flags encoded in the address
       uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        

        vm.startBroadcast();
        ShuffleTimeSlotSystem timeSlotSystem = new ShuffleTimeSlotSystem(
            owner, // owner
            address(THE_FEDZ_NFT) // nftContract
        );

        // // // // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(FedzHook).creationCode, abi.encode(address(ARBITRUM_POOLMANAGER), owner, address(timeSlotSystem)));
        console.log("this:", address(this));
        console.log("Hook deployed to:", address(hookAddress));
        console.log("salt:");
        console.logBytes32(salt);
        console.log("this", address(this));
        FedzHook TheFedzHook = new FedzHook{salt: salt}(IPoolManager(address(ARBITRUM_POOLMANAGER)), owner, address(timeSlotSystem));
        // console.log("Hook deployed to:", address(TheFedzHook));
        // console.log("Expected:", address(hookAddress));
        // require(address(TheFedzHook) == hookAddress, "FedzHookScript: hook address mismatch");
        // // Log the address of the deployed contract
        // console.log("Hook deployed to:", address(TheFedzHook));

        // // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
