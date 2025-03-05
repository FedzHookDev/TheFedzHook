// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/StdCheats.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

// forge script script/01_CreatePool.s.sol:CreatePoolScript --private-key <PK> --rpc-url https://arbitrum.rpc.subquery.network/public --etherscan-api-key 6N6Q2DRTUHGIVZ462FXWCX8AW7JPJTZBQ3 --broadcast -vvvv --verify
contract CreatePoolScript is Script, StdCheats {
    using CurrencyLibrary for Currency;
    address constant ARBITRUM_POOLMANAGER = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); // Arbitrum pool manager deployed to GOERLI
    address USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address
    address constant HOOK_ADDRESS = address(0x3e17096a281831Af89106c6060D849E21ab24AC0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!

    IPoolManager manager = IPoolManager(ARBITRUM_POOLMANAGER);

    function run() external {
        // sort the tokens!
        address token0 = uint160(USDT) < uint160(FUSD) ? USDT : FUSD;
        address token1 = uint160(USDT) < uint160(FUSD) ? FUSD : USDT;
        uint24 swapFee = 4000;
        int24 tickSpacing = 10;
        // deployCodeTo("lib/v4-core/src/PoolManager.sol", address(ARBITRUM_POOLMANAGER));

        // floor(sqrt(1) * 2^96)
        uint160 startingPrice = 79228162514264337593543950336;

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

        vm.broadcast();
        manager.initialize(pool, startingPrice);
    }
}
