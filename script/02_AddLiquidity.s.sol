// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {FedzHook} from "../src/FedzHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {TimeSlotSystem} from "../src/TimeSlotSystem.sol";
import {TheFedz} from "../src/TheFedz.sol";
import {FedzModifyLiquidityWrapper, IFedzModifyLiquidityWrapper} from "../src/FedzModifyLiquidityWrapper.sol";
import {FedzSwapWrapper} from "../src/FedzSwapWrapper.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

interface IArbitrumPoolManager is IPoolManager {
    function initialize(PoolKey memory pool, uint160 startingPrice) external;
}

// forge script script/02_AddLiquidity.s.sol:AddLiquidityScript --private-key 0x534012a5d0a91ea1f7902203f7f5c29fffcde18d439a28c48f0c6d9eb18521ab --rpc-url https://arbitrum.rpc.subquery.network/public
// forge script script/02_AddLiquidity.s.sol:AddLiquidityScript --rpc-url https://arbitrum.rpc.subquery.network/public
contract AddLiquidityScript is Script, StdCheats {
    using CurrencyLibrary for Currency;

    int constant LIQUIDITY_SIZE = 452552724530000;
    // uint constant LIQUIDITY_SIZE = 1000e18;
    address constant ARBITRUM_POOLMANAGER = address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32); // Arbitrum pool manager deployed to GOERLI
    address USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address
    address constant HOOK_ADDRESS = address(0x3e17096a281831Af89106c6060D849E21ab24AC0); //address of the hook contract deployed to goerli -- you can use this hook address or deploy your own!
    address owner = 0x833e421145863237e9B372dbA99EcF49C98956fb;

    PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(address(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32));

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    address MOCK_USDT = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // Mock USDT address
    address MOCK_FUSD = address(0x894341be568Eae3697408c420f1d0AcFCE6E55f9); // Mock USDC address

    uint256 depegThreshold = 281474976710656; //0.9 USDT per FUSD in Q64.96 format

    TimeSlotSystem timeSlotSystem;
    TheFedz theFedz;
    address token0;
    address token1;
    FedzHook TheFedzHook;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    address player0 = makeAddr("PLAYER_0");
    address player1 = makeAddr("PLAYER_1");
    address player2 = makeAddr("PLAYER_2");
    address player3 = makeAddr("PLAYER_3");
    address player4 = makeAddr("PLAYER_4");
    address player5 = makeAddr("PLAYER_5");
    address player6 = makeAddr("PLAYER_6");
    address player7 = makeAddr("PLAYER_7");
    address player8 = makeAddr("PLAYER_8");
    address player9 = makeAddr("PLAYER_9");
    address player10 = makeAddr("PLAYER_10");
    address player11 = makeAddr("PLAYER_11");
    address player12 = makeAddr("PLAYER_12");
    address player13 = makeAddr("PLAYER_13");

    function setUp() public {
        // deployCodeTo("PoolManager.sol", 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32);
    }
    function run() external {
        vm.stopPrank();

        //////////////////////////
        // DEPLOYMENTS
        //////////////////////////
        uint160 startingPrice = 79228162514264337593543950336;
        bytes memory hookData = abi.encode(block.timestamp);

        token0 = uint160(USDT) < uint160(FUSD) ? USDT : FUSD;
        token1 = uint160(USDT) < uint160(FUSD) ? FUSD : USDT;
        uint24 swapFee = 4000; // 0.40% fee tier
        int24 tickSpacing = 10;
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        theFedz = new TheFedz(owner);
        timeSlotSystem = new TimeSlotSystem(
            1 hours, // slotDuration
            24 hours, // roundDuration
            owner, // owner
            address(theFedz) // nftContract
        );
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(FedzHook).creationCode, abi.encode(owner,address(ARBITRUM_POOLMANAGER),address(theFedz),MOCK_USDT,MOCK_FUSD,depegThreshold, address(timeSlotSystem)));
        TheFedzHook = new FedzHook{salt: salt}(owner, IPoolManager(address(ARBITRUM_POOLMANAGER)),address(theFedz),MOCK_USDT,MOCK_FUSD,depegThreshold, address(timeSlotSystem));
        FedzModifyLiquidityWrapper fedzModifyLiquidityWrapper = new FedzModifyLiquidityWrapper(address(TheFedzHook), swapFee, tickSpacing, ARBITRUM_POOLMANAGER);
        FedzSwapWrapper fedzSwapRouter = new FedzSwapWrapper(address(TheFedzHook), swapFee, tickSpacing, ARBITRUM_POOLMANAGER);
        TheFedzHook.setFedzPoolWrapper(address(fedzModifyLiquidityWrapper), address(fedzSwapRouter));

        //////////////////////////
        // Create pool
        //////////////////////////
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        IArbitrumPoolManager(address(lpRouter)).initialize(pool, startingPrice);

        //////////////////////////
        // Setup player: NFT, tokens grants
        //////////////////////////
        vm.prank(owner);
        IERC20(token0).transfer(player0, 100);
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        IERC20(token1).transfer(player0, 100);
        vm.startPrank(owner);
        theFedz.adminMint(player0, 2);
        theFedz.adminMint(player1, 1);
        theFedz.adminMint(player2, 1);
        theFedz.adminMint(player3, 1);
        theFedz.adminMint(player4, 2);
        theFedz.adminMint(player5, 1);
        theFedz.adminMint(player6, 4);
        theFedz.adminMint(player7, 1);
        theFedz.adminMint(player8, 1);
        theFedz.adminMint(player9, 3);
        theFedz.adminMint(player10, 2);
        theFedz.adminMint(player11, 1);
        theFedz.adminMint(player12, 1);
        theFedz.adminMint(player13, 1);
        vm.stopPrank();
        require(theFedz.balanceOf(player0) == 2, "not correct balance");

        //////////////////////////
        // Times slot system activation
        //////////////////////////
        // vm.prank(owner);
        // timeSlotSystem.updatePlayerSlots();
        vm.prank(owner);
        // uint256 random = uint(keccak256(abi.encodePacked(block.timestamp, uint(843828931223423))));
        uint256 random = uint(keccak256(abi.encodePacked(uint256(10000000), uint(843828931223423))));
        timeSlotSystem.startNewRound(random);

        //////////////////////////
        // Add liquidity
        //////////////////////////
        vm.prank(player0);
        IERC20(token0).approve(address(fedzModifyLiquidityWrapper), 20);
        vm.prank(player0);
        IERC20(token1).approve(address(fedzModifyLiquidityWrapper), 20);
        FedzModifyLiquidityWrapper.FedzModifyLiquidityParams memory modifyLiquidityParams = IFedzModifyLiquidityWrapper.FedzModifyLiquidityParams({
            token0: token0,
            token1: token1,
            amount0: 1,
            amount1: 1,
            tickLower: -600,
            tickUpper: 600,
            liquidityDelta: 80
        });
        vm.prank(player0);
        fedzModifyLiquidityWrapper.modifiyLiquidity(modifyLiquidityParams);
        console.log("done add liquidity");

        //////////////////////////
        // Remove liquidity
        //////////////////////////
        // modifyLiquidityParams = FedzModifyLiquidityRouter.FedzModifyLiquidityParams({
        //     token0: token0,
        //     token1: token1,
        //     amount0: 1,
        //     amount1: 1,
        //     tickLower: -600,
        //     tickUpper: 600,
        //     liquidityDelta: -80
        // });
        // vm.prank(player);
        // fedzModifyLiquidityRouter.modifiyLiquidity(modifyLiquidityParams);
        // console.log("done remove liquidity");

        // IERC20(token0).balanceOf(address(fedzModifyLiquidityWrapper));
        // IERC20(token1).balanceOf(address(fedzModifyLiquidityWrapper));

        // IERC20(token0).balanceOf(player);
        // IERC20(token1).balanceOf(player);
        //////////////////////////
        // swap token0 to token1
        //////////////////////////
        bool zeroForOne = true;
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 1,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });
         vm.prank(player0);
        IERC20(token0).approve(address(fedzSwapRouter), 20);
        vm.prank(player0);
        IERC20(token1).approve(address(fedzSwapRouter), 20);
        vm.prank(player0);
        fedzSwapRouter.swap(token0, token1, swapParams);
    }
}
