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

contract FedzHookTest is Test, Fixtures {
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

    //Utils
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
        deal(address(token), address(this), 10e18);


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
            token.safeIncreaseAllowance(toApprove[i], 10e6);
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


        console2.log("Deploying Hook");
        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG  | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        deployCodeTo("FedzHook.sol:FedzHook", abi.encode(address(this),manager,address(this),USDT,USDC,900), flags);
        


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

        console2.log("Minting position");


        (tokenId,) = posm.mint(
            config,
            10e7,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        console2.log("setup done");
        

    


    
    }

    function testCounterHooks() public {
        // positions were created in setup()
       

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e6; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);

       
    }

    function testLiquidityHooks() public {
        // positions were created in setup()
       
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
}
