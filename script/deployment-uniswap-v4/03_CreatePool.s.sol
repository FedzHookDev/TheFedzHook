// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {FedzHook} from "../../src/FedzHook.sol";
import {HookMiner} from "../../test/utils/HookMiner.sol";
import {RoundRobinTimeSlotSystem} from "../../src/RoundRobinTimeSlotSystem.sol";
import {TheFedz} from "../../src/TheFedz.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";


// forge script script/deployment-uniswap-v4/03_CreatePool.s.sol:CreatePoolScript --private-key <PK> --rpc-url https://arbitrum.rpc.subquery.network/public --etherscan-api-key 6N6Q2DRTUHGIVZ462FXWCX8AW7JPJTZBQ3 --verify --broadcast
// forge script script/deployment-uniswap-v4/03_CreatePool.s.sol:CreatePoolScript --rpc-url https://arbitrum.rpc.subquery.network/public

contract CreatePoolScript is Script, StdCheats {
    using CurrencyLibrary for Currency;

    address constant ARBITRUM_POOLMANAGER = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); // Arbitrum pool manager deployed to GOERLI
    address USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address
    address constant FEDZ_HOOK = address(0x3e17096a281831Af89106c6060D849E21ab24AC0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!
    TheFedz theFedz;
    address token0;
    address token1;
    FedzHook TheFedzHook;

    function setUp() public {}

    function run() external {
        token0 = uint160(USDT) < uint160(FUSD) ? USDT : FUSD;
        token1 = uint160(USDT) < uint160(FUSD) ? FUSD : USDT;

        uint160 startingPrice = 79228162514264337593543950336;
        uint24 swapFee = 4000; // 0.40% fee tier
        int24 tickSpacing = 10;
        //////////////////////////
        // Create pool
        //////////////////////////
        vm.startBroadcast();
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(FEDZ_HOOK)
        });
        IPoolManager(ARBITRUM_POOLMANAGER).initialize(pool, startingPrice);
        vm.stopBroadcast();
    }
}
