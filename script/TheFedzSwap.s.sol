// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract SwapScript is Script {

     // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");


    // PoolSwapTest Contract address on Sepolia
    PoolSwapTest swapRouter = PoolSwapTest(0x841B5A0b3DBc473c8A057E2391014aa4C4751351);

    address constant SEPOLIA_POOLMANAGER = address(0xc021A7Deb4a939fd7E661a0669faB5ac7Ba2D5d6); //sepolia pool manager deployed to GOERLI
    address constant MFUSD_ADDRESS = address(0xc7c06a77b481869ecc57E5432D03c3661406424D); //mUNI deployed to GOERLI -- insert your own contract address here
    address constant MUSDT_ADDRESS = address(0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f); //mUSDC deployed to GOERLI -- insert your own contract address here
    address constant HOOK_ADDRESS = address(0x4C3bb7E3eb22a1AED4f16D87A3427034E394cAc0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!


    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    function run() external {
        address token0 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MUSDT_ADDRESS : MFUSD_ADDRESS;
        address token1 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MFUSD_ADDRESS : MUSDT_ADDRESS;
        uint24 swapFee = 4000;
        int24 tickSpacing = 60;

        // Using a hooked pool
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // approve tokens to the swap router
        vm.startBroadcast(deployerPrivateKey);
        IERC20(token0).approve(address(swapRouter), type(uint256).max);
        IERC20(token1).approve(address(swapRouter), type(uint256).max);

        // ---------------------------- //
        // Swap 100e18 token0 into token1 //
        // ---------------------------- //
        bool zeroForOne = true;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 10e6,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        // in v4, users have the option to receieve native ERC20s or wrapped ERC1155 tokens
        // here, we'll take the ERC20s
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        bytes memory hookData = new bytes(0);
        
        swapRouter.swap(pool, params, testSettings, hookData);
        vm.stopBroadcast();
    }
}
