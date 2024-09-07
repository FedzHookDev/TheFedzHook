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
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {FedzHook} from "../src/FedzHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PositionConfig} from "v4-periphery/src/libraries/PositionConfig.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SortTokens} from "v4-core/test/utils/SortTokens.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {TimeSlotSystem} from "../src/TimeSlotSystem.sol";
import {MockERC721} from "../src/MockERC721.sol";   
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FedzHookTest is Test, Fixtures, IERC721Receiver {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    FedzHook hook;
    PoolId poolId;

    uint256 tokenId;
    PositionConfig config;

    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;  //Mainnet USDT
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  //Mainnet USDC

    address test = address(this);

    uint256 depegThreshold = 281474976710656; //0.9 USDT per FUSD in Q64.96 format

    MockERC721 mockNFT = new MockERC721("NFT", "NFT", address(this));
    

    //NFT.mint(address(this)); //Mint Mock NFT

    

    TimeSlotSystem turnSystem = new TimeSlotSystem(
            1 hours, // slotDuration
            24 hours, // roundDuration
            address(this), // owner
            address(mockNFT) // nftContract
        );


    //Utils
    //NFT receiving function
     function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    // You must have first initialised the routers with deployFreshManagerAndRouters
    // If you only need the currencies (and not approvals) call deployAndMint2Currencies
    function deployMintAndApprove2CurrenciesFixed() internal returns (Currency, Currency) {
        console2.log("Deploying currencies");
        Currency _currencyA = deployMintAndApproveCurrencyFixed(IERC20(USDT));
        Currency _currencyB = deployMintAndApproveCurrencyFixed(IERC20(USDC));
        
        console2.log("Sorting currencies");
        //(currency0, currency1) = SortTokens.sort(MockERC20(Currency.unwrap(_currencyA)), MockERC20(Currency.unwrap(_currencyB)));
         if (address(USDT) < address(USDC)) {
            (_currencyA, _currencyB) = (Currency.wrap(address(USDT)), Currency.wrap(address(USDC)));
        } else {
            (_currencyA, _currencyB) = (Currency.wrap(address(USDC)), Currency.wrap(address(USDT)));
        }
        return (_currencyA, _currencyB);
    }

    function deployMintAndApproveCurrencyFixed(IERC20 token) internal returns (Currency currency) {
        //MockERC20 token = deployTokens(1, 2 ** 255)[0];
        deal(address(token), address(this), 10e40);


        console2.log("Approving routers");
        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            token.safeIncreaseAllowance(toApprove[i], type(uint256).max);
            console2.log("Approved", toApprove[i]);
        }

        return Currency.wrap(address(token));
    }

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();

        (currency0, currency1) = deployMintAndApprove2CurrenciesFixed();

        console2.log("address of currency 0", address(Currency.unwrap(currency0)));
        console2.log("address of currency 1", address(Currency.unwrap(currency1)));
        console2.log("Deploying POSM");
        deployAndApprovePosm(manager);

        
        mockNFT.mint(test); //Mint Mock NFT


        console2.log("Deploying Hook");
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG  | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );

        /*
        To calculate the appropriate depegThreshold for a depeg up to 0.9$ when both USDC and USDT have 6 decimals, we need to consider the following:

            The price is typically represented in terms of token1 per token0.
            We want to detect when the price goes below 0.9 USDT per FUSD.
            Both tokens have 6 decimals, so we don't need to adjust for decimal differences.
            Here's how we can calculate it:

            First, let's consider the price as a ratio: 0.9 USDT / 1 FUSD

            Since both tokens have 6 decimals, we can represent this as: 900,000 / 1,000,000 = 0.9

            In Uniswap V4, prices are often represented as fixed-point Q64.96 numbers. To convert our price to this format, we need to multiply by 2^96:

            0.9 * 2^96 = 900,000 / 1,000,000 * 2^96 ≈ 79,228,162,514,264,337,593,543,950,336

            The square root of this number is what's typically used in Uniswap V4 for price representation:

            √(0.9 * 2^96) ≈ 281,474,976,710,656


        */


       

        deployCodeTo("FedzHook.sol:FedzHook", abi.encode(address(this),manager,address(mockNFT),USDT,USDC,depegThreshold, address(turnSystem)), flags);
        


        hook = FedzHook(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 100, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        console2.log("Deploying position");

        // Provide full-range liquidity to the pool
        config = PositionConfig({
            poolKey: key,
            tickLower: TickMath.minUsableTick(key.tickSpacing),
            tickUpper: TickMath.maxUsableTick(key.tickSpacing)
        });
        /*
        console2.log("Minting position");
        mockNFT.mintToContract(address(posm)); //Mint Mock NFT
        mockNFT.mintToContract(address(msg.sender)); //Mint Mock NFT
        mockNFT.mintToContract(address(manager)); //Mint Mock NFT

        vm.prank(address(manager));
        turnSystem.registerPlayer();

        vm.prank(address(msg.sender));
        turnSystem.registerPlayer();


        vm.prank(address(posm));
        turnSystem.registerPlayer();
        */

       

        

        console2.log("is addres nft holder ? :" , mockNFT.isNFTHolder(address(posm)));
        //turnSystem.startNewRound();

        console2.log("msg sender:", msg.sender);
        console2.log("manager address:", address(manager));
        console2.log("is addres nft holder ? :" , mockNFT.isNFTHolder(address(manager)));

        (tokenId,) = posm.mint(
            config,
            10e7,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

          // positions were created in setup()
        mockNFT.mintToContract(address(swapRouter)); //Mint Mock NFT
        vm.prank(address(swapRouter));
        turnSystem.registerPlayer(); //join queue for swapper

        vm.warp(block.timestamp + 25 hours); //warp so its swapRouter turn

        

        console2.log("setup done");
        


    
    }

    function testSwap() public {
        if(turnSystem.getCurrentPlayer() != address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); //warp so its SwapRouter turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());        // positions were created in setup()
       //sell USDC for USDT

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e6; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assertGt(FedzHook(hook).getCurrentPrice(key), depegThreshold);

       
    }

    function testSwapDuringTurn() public {
        if(turnSystem.getCurrentPlayer() != address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); //warp so its posm turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());
        // Start a turn for this address
        (uint256 startTime, uint256 endTime) = turnSystem.getNextActionWindow(address(swapRouter));

        console2.log("next player can act from:" , startTime);
        console2.log("next player can act until:" , endTime);

        // Perform a test swap
        bool zeroForOne = true;
        int256 amountSpecified = -1e6;
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assertGt(FedzHook(hook).getCurrentPrice(key), depegThreshold);
    }

    function testSwapOutsideTurn() public {
        if(turnSystem.getCurrentPlayer() == address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); //warp so its not swapRouter turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());
        // Ensure it's not this address's turn
        console2.log("current player:" , turnSystem.getCurrentPlayer());

        // Attempt a swap, which should revert
        bool zeroForOne = true;
        int256 amountSpecified = -1e6;
        vm.expectRevert();
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }


    function testDepegSwapShouldRevert() public {
         if(turnSystem.getCurrentPlayer() != address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); //warp so its SwapRouter turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());
       // sell USDC for USDT

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e30; // negative number indicates exact input swap!
        vm.expectRevert(); //expect revert since the swap price after is below the depeg threshold
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

       
       
    }

    function testRemoveLiquidityInTurn() public {
        // positions were created in setup()
        if(turnSystem.getCurrentPlayer() != address(posm)){
           vm.warp(block.timestamp + 61 minutes); //warp so its posm turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());

        // remove liquidity
        uint256 liquidityToRemove = 1e6;
        posm.decreaseLiquidity(
            tokenId,
            config,
            liquidityToRemove,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

       
    }

    function testRemoveLiquidityBeforeTurn() public {
        // positions were created in setup()
        if(turnSystem.getCurrentPlayer() == address(posm)){
           vm.warp(block.timestamp + 61 minutes); //warp so its not posm turn
        }
        console2.log("current player:" , turnSystem.getCurrentPlayer());

        // remove liquidity
        uint256 liquidityToRemove = 1e6;

        // Move vm.expectRevert() here, right before the call that should revert
        vm.expectRevert();
        posm.decreaseLiquidity(
            tokenId,
            config,
            liquidityToRemove,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        //Note test does work since it reverts, but forge don't account for reverts in test results isnce its a low level operation
    }

    function testAddLiquidityNormalState() public {
        if(turnSystem.getCurrentPlayer() != address(posm)){
           vm.warp(block.timestamp + 61 minutes); // warp so it's posm's turn
        }
        console2.log("current player:", turnSystem.getCurrentPlayer());

        // Ensure the price is above the depeg threshold
        uint160 currentPrice = hook.getCurrentPrice(key);
        assertGt(currentPrice, depegThreshold, "Price should be above depeg threshold");

        // Add liquidity
        uint128 liquidityToAdd = 1e18;
        int24 tickLower = -120;
        int24 tickUpper = 120;

        // Provide full-range liquidity to the pool
        config = PositionConfig({
            poolKey: key,
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        //vm.expectEmit(true, true, true, true);
        //emit LiquidityAdded(address(posm), liquidity, tickLower, tickUpper);

        (tokenId,) = posm.mint(
            config,
            liquidityToAdd,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        // Additional assertions can be added here if needed
    }

    function testAddLiquidityDepeggedStateAbovePrice() public {
        /*
        if(turnSystem.getCurrentPlayer() != address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); // warp so it's posm's turn
        }
        console2.log("current player:", turnSystem.getCurrentPlayer());

        // Simulate a depeg by performing a large swap
        bool zeroForOne = true;
        int256 amountSpecified = -1e30; // Large swap to cause depeg
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        uint160 currentPrice = hook.getCurrentPrice(key);
        assertLt(currentPrice, depegThreshold, "Price should be below depeg threshold");

        if(turnSystem.getCurrentPlayer() != address(posm)){
           vm.warp(block.timestamp + 61 minutes); // warp so it's posm's turn
        }
        console2.log("current player:", turnSystem.getCurrentPlayer());

        // Try to add liquidity above current price
        uint128 liquidityToAdd = 1e18;
        int24 tickLower = TickMath.getTickAtSqrtPrice(currentPrice) + 1;
        int24 tickUpper = TickMath.getTickAtSqrtPrice(currentPrice) + 120;

        // Provide full-range liquidity to the pool
        config = PositionConfig({
            poolKey: key,
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        //vm.expectEmit(true, true, true, true);
        //emit LiquidityAdded(address(posm), liquidity, tickLower, tickUpper);

        (tokenId,) = posm.mint(
            config,
            liquidityToAdd,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
        */
    }

    function testAddLiquidityDepeggedStateBelowPrice() public {
        /*
        if(turnSystem.getCurrentPlayer() != address(swapRouter)){
           vm.warp(block.timestamp + 61 minutes); // warp so it's posm's turn
        }
        console2.log("current player:", turnSystem.getCurrentPlayer());

        // Simulate a depeg by performing a large swap
        bool zeroForOne = true;
        int256 amountSpecified = -1e24; // Large swap to cause depeg
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        uint160 currentPrice = hook.getCurrentPrice(key);
        assertLt(currentPrice, depegThreshold, "Price should be below depeg threshold");

        if(turnSystem.getCurrentPlayer() != address(posm)){
           vm.warp(block.timestamp + 61 minutes); // warp so it's posm's turn
        }
        console2.log("current player:", turnSystem.getCurrentPlayer());

        // Add liquidity below current price
        uint128 liquidityToAdd = 1e18;
        console2.log("current tick  price:", TickMath.getTickAtSqrtPrice(currentPrice));
        console2.log("min tick usable:", TickMath.minUsableTick(key.tickSpacing));
        int24 tickLower =  -736980;
        int24 tickUpper = -736920;

        console2.log("tick lower:", tickLower);
        console2.log("tick upper:", tickUpper);

        // Provide full-range liquidity to the pool
        config = PositionConfig({
            poolKey: key,
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        //vm.expectEmit(true, true, true, true);
        //emit LiquidityAdded(address(posm), liquidity, tickLower, tickUpper);

        (tokenId,) = posm.mint(
            config,
            liquidityToAdd,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        // Additional assertions can be added here if needed
        */
    }

}
