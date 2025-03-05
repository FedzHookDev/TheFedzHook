// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {IUniversalRouter} from "@uniswap/universal-router/contracts/interfaces/IUniversalRouter.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPositionDescriptor} from "@uniswap/v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {IStateView} from "@uniswap/v4-periphery/src/interfaces/IStateView.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


// forge script script/02_AddLiquidityAndSwapViaEOA.s.sol:AddLiquidityAndSwapViaEOA --private-key <PK> --rpc-url https://arbitrum.rpc.subquery.network/public
// forge script script/02_AddLiquidityAndSwapViaEOA.s.sol:AddLiquidityAndSwapViaEOA --rpc-url https://arbitrum.rpc.subquery.network/public
contract AddLiquidityAndSwapViaEOA is Script, StdCheats {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    int constant LIQUIDITY_SIZE = 452552724530000;
    // uint constant LIQUIDITY_SIZE = 1000e18;
    address constant ARBITRUM_POOLMANAGER = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); // Arbitrum pool manager deployed to GOERLI
    address USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address
    address constant HOOK_ADDRESS = address(0x3e17096a281831Af89106c6060D849E21ab24AC0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!
    address constant UNIVERSAL_ROUTER = 0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3;
    address owner = 0x833e421145863237e9B372dbA99EcF49C98956fb;
    address STATE_VIEWER = 0x76Fd297e2D437cd7f76d50F01AfE6160f86e9990;
    // PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32));

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    address MOCK_USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address MOCK_FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address

    uint256 depegThreshold = 281474976710656; //0.9 USDT per FUSD in Q64.96 format

    address token0;
    address token1;
    uint24 swapFee = 4000; // 0.40% fee tier
    int24 tickSpacing = 10;
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;
    uint160 flags = uint160(
        Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
    );
    address player = makeAddr("TEST");
    int24 tickLower = -276810;
    int24 tickUpper = -275830;
    uint256 liquidityDelta = 33837499809738371;
    uint128 amount0Max = 2030452988375913;
    uint128 amount1Max = 100000000000000;

    IPositionManager positionManager;
    // AllowanceTransfer allowanceTransfer;
    address PERMIT_2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    // FedzRouter lpRouter;
    uint256 constant V4_SWAP = 0x10;

    function setUp() public {
        positionManager = IPositionManager(0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869);
    }
    function run() external {
  
        //////////////////////////
        // DEPLOYMENTS
        //////////////////////////
        uint160 startingPrice = 79228162514264337593543950336000000;

        token0 = uint160(USDT) < uint160(FUSD) ? USDT : FUSD;
        token1 = uint160(USDT) < uint160(FUSD) ? FUSD : USDT;
        address hookAddress = address(0);
        //////////////////////////
        // Setup player: NFT, tokens grants
        //////////////////////////
        vm.prank(owner);
        IERC20(token0).transfer(player, 1000000);
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        IERC20(token1).transfer(player, 1000000);
        //////////////////////////
        // Create pool
        //////////////////////////
        Currency currency0 = Currency.wrap(token0); // tokenAddress1 = 0 for native ETH
        Currency currency1 = Currency.wrap(token1);
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        IPoolManager(address(ARBITRUM_POOLMANAGER)).initialize(pool, startingPrice);


        //////////////////////////
        // Add liquidity
        //////////////////////////
        vm.prank(player);
        IERC20(token0).approve(address(PERMIT_2), 100000);
        vm.prank(player);
        IAllowanceTransfer(PERMIT_2).approve(token0, address(positionManager), uint160(100000), uint48(block.timestamp + 2 hours));

    
        vm.prank(player);
        IERC20(token1).approve(address(PERMIT_2), 100000);
        vm.prank(player);
        IAllowanceTransfer(PERMIT_2).approve(token1, address(positionManager), uint160(100000), uint48(block.timestamp + 2 hours));
        

        bytes memory hookData = hex"";
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(pool, tickLower, tickUpper, liquidityDelta, amount0Max, amount1Max, player, hookData);
        params[1] = abi.encode(currency0, currency1);
        uint256 deadline = block.timestamp + 60;

        vm.prank(player);
        IPositionManager(address(positionManager)).modifyLiquidities(
            abi.encode(actions, params),
            deadline
        );
        // //////////////////////////
        // // Increase liquidity
        // //////////////////////////
        // actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
        // params = new bytes[](2);
        // params[0] = abi.encode(tokenId, liquidityDelta, amount0Max, amount1Max, hookData);
        // params[1] = abi.encode(currency0, currency1);
        // deadline = block.timestamp + 60;
        // vm.prank(player);
        // IPositionManager(address(positionManager)).modifyLiquidities(
        //     abi.encode(actions, params),
        //     deadline
        // );
        // //////////////////////////
        // // Decrease liquidity
        // //////////////////////////
        // actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        // params = new bytes[](2);
        // params[0] = abi.encode(tokenId, liquidityDelta, amount0Min, amount1Min, hookData);
        // params[1] = abi.encode(currency0, currency1, player);
        // deadline = block.timestamp + 60;
        // vm.prank(player);
        // IPositionManager(address(positionManager)).modifyLiquidities(
        //     abi.encode(actions, params),
        //     deadline
        // );

        //////////////////////////
        // swap token0 to token1
        //////////////////////////
        bool zeroForOne = true;
        vm.prank(player);
        IERC20(token0).approve(address(PERMIT_2), 20);
        vm.prank(player);
        IAllowanceTransfer(PERMIT_2).approve(token0, address(UNIVERSAL_ROUTER), uint160(100000), uint48(block.timestamp + 2 hours));
        vm.prank(player);
        bytes memory commands = abi.encodePacked(uint8(V4_SWAP));
        actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        uint128 amountIn = 20;
        uint128 minAmountOut = 2;

        params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: pool,
                zeroForOne: true,            // true if we're swapping token0 for token1
                amountIn: amountIn,          // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("")             // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(pool.currency0, amountIn);

        // // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(pool.currency1, minAmountOut);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);
        // IUniversalRouter(UNIVERSAL_ROUTER).execute(commands, inputs, block.timestamp + 1000);

        // // //////////////////////////
        // // // Burn liquidity
        // // //////////////////////////
        // // // deployCodeTo("lib/v4-periphery/src/PositionManager.sol", hex"000000000000000000000000360e68faccca8ca495c1b759fd9eee466db9fb32000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba300000000000000000000000000000000000000000000000000000000000493e0000000000000000000000000e2023f3fa515cf070e07fd9d51c1d236e07843f400000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1", address(positionManager));

        // // console.log("tokenId: ");
        // // console.logUint(tokenId);
        // // vm.prank(player);
        // // // IERC721(address(positionManager)).approve(address(positionManager), tokenId);
        // // actions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        // // params = new bytes[](2);
        // // params[0] = abi.encode(tokenId, amount0Min, amount1Min, hookData);
        // // params[1] = abi.encode(currency0, currency1, player);
        // // deadline = block.timestamp + 60;
        // // IPositionManager(address(positionManager)).modifyLiquidities(
        // //     abi.encode(actions, params),
        // //     deadline
        // // );
    }

    function calculate_token0_amount(uint liquidity, uint sp, uint sa, uint sb) internal view returns(uint) {
        sp = Math.max(Math.min(sp, sb), sa);
        return liquidity * (sb - sp) / (sp * sb);
    }

    function calculate_token1_amount(uint liquidity, uint sp, uint sa, uint sb) internal view returns(uint) {
        sp = Math.max(Math.min(sp, sb), sa);
        return liquidity * (sp - sa);
    }
}
