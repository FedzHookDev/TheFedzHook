// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

contract AddLiquidityScript is Script {
    using CurrencyLibrary for Currency;

    address constant SEPOLIA_POOLMANAGER = address(0xf242cE588b030d0895C51C0730F2368680f80644); //sepolia pool manager deployed to GOERLI
    address constant MFUSD_ADDRESS = address(0xc7c06a77b481869ecc57E5432D03c3661406424D); //mUNI deployed to GOERLI -- insert your own contract address here
    address constant MUSDT_ADDRESS = address(0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f); //mUSDC deployed to GOERLI -- insert your own contract address here
    address constant HOOK_ADDRESS = address(0x4E4a9A0C097427A4A72B1386A031fd411adf8aC0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!

    PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(address(0x39BF2eFF94201cfAA471932655404F63315147a4));

    function run() external {
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // sort the tokens!
        address token0 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MUSDT_ADDRESS : MFUSD_ADDRESS;
        address token1 = uint160(MUSDT_ADDRESS) < uint160(MFUSD_ADDRESS) ? MFUSD_ADDRESS : MUSDT_ADDRESS;
        uint24 swapFee = 4000; // 0.40% fee tier
        int24 tickSpacing = 60;

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        uint256 provideToken0 = 100000e18;
        uint256 provideToken1 = 100000e18;

        // approve tokens to the LP Router
        vm.startBroadcast(deployerPrivateKey);
        IERC20(token0).approve(address(lpRouter), provideToken0);
        IERC20(token1).approve(address(lpRouter), provideToken1);

        // optionally specify hookData if the hook depends on arbitrary data for liquidity modification
        bytes memory hookData = new bytes(0);

        // logging the pool ID
        PoolId id = PoolIdLibrary.toId(pool);
        bytes32 idBytes = PoolId.unwrap(id);
        console.log("Pool ID Below");
        console.logBytes32(bytes32(idBytes));

        // Provide 10_000e18 worth of liquidity on the range of [-600, 600]
        lpRouter.modifyLiquidity(pool, IPoolManager.ModifyLiquidityParams(-600, 600, 10_00000e18, 0), hookData);

        vm.stopBroadcast();

    }
}
