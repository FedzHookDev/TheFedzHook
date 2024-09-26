// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {FedzHook} from "../src/FedzHook.sol";
import {CustomRouter} from "../src/CustomRouter.sol";
import {TimeSlotSystem} from "../src/TimeSlotSystem.sol";
import {MockERC721} from "../src/MockERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolSwapTest} from "../src/TestRouters/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "../src/TestRouters/PoolModifyLiquidityTest.sol";


contract FedzHookTestCustomRouter is Test, IERC721Receiver {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    FedzHook hook;

    IPoolManager manager;
    PoolKey key;
    PoolId poolId;

    //Routers
    PoolSwapTest swapRouter;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    MockERC721 mockNFT;
    TimeSlotSystem turnSystem;

    address constant POOL_MANAGER = 0xc021A7Deb4a939fd7E661a0669faB5ac7Ba2D5d6;
    address constant MOCK_FUSD = 0xc7c06a77b481869ecc57E5432D03c3661406424D;
    address constant MOCK_USDT = 0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f;

    uint256 constant DEPEG_THRESHOLD = 281474976710656; // 0.9 USDT per FUSD in Q64.96 format

    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336; // initial price one to one
    bytes constant ZERO_BYTES = new bytes(0);
    uint160 sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE + 1; // Set to minimum for one-way swap
    bytes32 ZERO_SALT = bytes32(0);


    

    function setUp() public {
        // Deploy mock contracts
        mockNFT = new MockERC721("NFT", "NFT", address(this), 'https://fedzfrontend-loris-epfl-loris-epfls-projects.vercel.app/NftPictures/nft_');
        turnSystem = new TimeSlotSystem(1 hours, 24 hours, address(this), address(mockNFT));

        // Deploy the PoolManager
        manager = IPoolManager(POOL_MANAGER);

        //Init currencies
        Currency currency0;
        Currency currency1;


        //Deploy Currencies
         if (address(MOCK_USDT) < address(MOCK_FUSD)) {
            (currency0, currency1) = (Currency.wrap(address(MOCK_USDT)), Currency.wrap(address(MOCK_FUSD)));
        } else {
            (currency0, currency1) = (Currency.wrap(address(MOCK_FUSD)), Currency.wrap(address(MOCK_USDT)));
        }

        console2.log("address of currency 0", address(Currency.unwrap(currency0)));
        console2.log("address of currency 1", address(Currency.unwrap(currency1)));

        deal(MOCK_FUSD, address(this), 1e40);
        deal(MOCK_USDT, address(this), 1e40);

        //Aprove Currencies
        IERC20(Currency.unwrap(currency0)).approve(address(manager), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(manager), type(uint256).max);
       

        // Deploy the hook
         address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG  | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );

        deployCodeTo("FedzHook.sol:FedzHook", abi.encode(address(this),manager,address(mockNFT),MOCK_USDT,MOCK_FUSD,DEPEG_THRESHOLD, address(turnSystem)), flags);

       
        hook = FedzHook(flags);
        key = PoolKey(currency0, currency1, 100, 60, IHooks(hook));
        poolId = key.toId();
        
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Deploy the CustomRouter
        swapRouter = new PoolSwapTest(IPoolManager(POOL_MANAGER));
        modifyLiquidityRouter = new PoolModifyLiquidityTest(IPoolManager(POOL_MANAGER));

        

        // Mint NFTs and register players
        mockNFT.mint(address(this));
        mockNFT.mintToContract(address(swapRouter));
        mockNFT.mintToContract(address(modifyLiquidityRouter));

        vm.prank(address(modifyLiquidityRouter));
        //turnSystem.registerPlayer();

        //turnSystem.registerPlayer();
        vm.prank(address(swapRouter));
        //turnSystem.registerPlayer();

        

        turnSystem.startNewRound();

        console2.log("current player", turnSystem.getCurrentPlayer());

        // Approve tokens for the router
        IERC20(MOCK_FUSD).approve(address(swapRouter), type(uint256).max);
        IERC20(MOCK_USDT).approve(address(swapRouter), type(uint256).max);

        IERC20(MOCK_FUSD).approve(address(modifyLiquidityRouter), type(uint256).max);
        IERC20(MOCK_USDT).approve(address(modifyLiquidityRouter), type(uint256).max);

        int24 tickLower = -120;
        int24 tickUpper = 120;
        int256 liquidity = 1e6;
        bytes memory addLiquidityData = abi.encode(address(this), "");
        
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(liquidity),
            salt: ZERO_SALT
        }), ZERO_BYTES);
    }

    function testSwap() public {
        // Ensure it's the router's turn
        //vm.warp(block.timestamp + 1 hours);
        
        // Prepare swap parameters
        bool zeroForOne = true;
        int256 amountSpecified = -1e6; // Exact input of 1 FUSD

        console2.log("current player", turnSystem.getCurrentPlayer());

        
        // Encode SwapParams
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        
        
        // Perform the swap
        BalanceDelta delta = swapRouter.swap(key, params,testSettings,  ZERO_BYTES);

        // Assert the swap was successful
        assertLt(delta.amount0(), 0);
        assertGt(delta.amount1(), 0);
    }


    function testAddLiquidity() public {
        // Ensure it's this contract's turn
        vm.warp(block.timestamp + 2 hours);

        // Add liquidity
        int24 tickLower = -120;
        int24 tickUpper = 120;
        int256 liquidity = 1e18;
        bytes memory addLiquidityData = abi.encode(address(this), "");
        
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(liquidity),
            salt: ZERO_SALT
        }), ZERO_BYTES);

        // Assert liquidity was added successfully
        // You might need to implement a way to check the liquidity in the pool
    }

    function testRemoveLiquidity() public {
        // First add liquidity
        testAddLiquidity();

        // Ensure it's this contract's turn again
        vm.warp(block.timestamp + 24 hours);

        // Remove liquidity
        int24 tickLower = -120;
        int24 tickUpper = 120;
        int256 liquidity = 1e18;
        bytes memory removeLiquidityData = abi.encode(address(this), "");
        
        
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: -int256(liquidity),
            salt: ZERO_SALT
        }), ZERO_BYTES);

        // Assert liquidity was removed successfully
        // You might need to implement a way to check the liquidity in the pool
    }

    function testSwapOutsideTurn() public {
        // Ensure it's not the router's turn
        vm.warp(block.timestamp + 30 minutes);
        
        // Attempt a swap, which should revert
        int256 amountSpecified = -1e6;
        bytes memory swapData = abi.encode(address(this), "");
        bool zeroForOne = true;

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        

        vm.expectRevert("Not player's turn");

        BalanceDelta delta = swapRouter.swap(key, params, testSettings,  ZERO_BYTES);
    }

    function testDepegSwapShouldRevert() public {
        // Ensure it's the router's turn
        vm.warp(block.timestamp + 1 hours);
        
        // Perform a large swap to cause a depeg
        int256 amountSpecified = -1e30;
        bytes memory swapData = abi.encode(address(this), "");
        bool zeroForOne = true;

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        vm.expectRevert("Price is below depeg threshold");

        BalanceDelta delta = swapRouter.swap(key, params,testSettings,  ZERO_BYTES);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
