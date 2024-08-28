// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

contract CreatePoolScript is Script {
    using CurrencyLibrary for Currency;

    //addresses with contracts deployed
    address constant SEPOLIA_POOLMANAGER = address(0xc021A7Deb4a939fd7E661a0669faB5ac7Ba2D5d6); //sepolia pool manager deployed to GOERLI
    address constant MFUSD_ADDRESS = address(0xc7c06a77b481869ecc57E5432D03c3661406424D); //mUNI deployed to GOERLI -- insert your own contract address here
    address constant MUSDT_ADDRESS = address(0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f); //mUSDC deployed to GOERLI -- insert your own contract address here
    address constant HOOK_ADDRESS = address(0x4C3bb7E3eb22a1AED4f16D87A3427034E394cAc0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!

    IPoolManager manager = IPoolManager(SEPOLIA_POOLMANAGER);

    function run() external {
         // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // sort the tokens!
        address token0 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MUSDT_ADDRESS : MFUSD_ADDRESS;
        address token1 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MFUSD_ADDRESS : MUSDT_ADDRESS;
        uint24 swapFee = 4000;
        int24 tickSpacing = 60;

        // floor(sqrt(1) * 2^96)
        uint160 startingPrice = 79228162514264337593543950336; // 1 to 1 in Q96

        bytes memory hookData = abi.encode(block.timestamp);

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // Turn the Pool into an ID so you can use it for modifying positions, swapping, etc.
        PoolId id = PoolIdLibrary.toId(pool);
        bytes32 idBytes = PoolId.unwrap(id);

        console.log("Pool ID Below");
        console.logBytes32(bytes32(idBytes));

        vm.startBroadcast(deployerPrivateKey);

        //Initialize the pool
        manager.initialize(pool, startingPrice, hookData);

        vm.stopBroadcast();

    }
}
