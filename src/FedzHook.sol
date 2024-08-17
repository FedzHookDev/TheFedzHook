import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {NFTAccessScheduler} from "./NFTAccessScheduler.sol";
import {NFTWhitelist} from "./NFTWhitelist.sol";


contract FedzHook is BaseHook,  NFTWhitelist {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 depegThreshold;
    int24 depegTick;
    address USDC;
    address FUSD;

    address public manager;

    struct UserLiquidity{
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
    }
   
    constructor(address _owner, IPoolManager _poolManager, address _nftContract) BaseHook(_poolManager) NFTWhitelist(_nftContract, _owner) {
        manager = _owner;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory){
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }


    /*
    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: true,
            afterInitialize: true,
            beforeModifyPosition: true,
            afterModifyPosition: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true
        });
    }
    */

    function beforeAddLiquidity(
        address owner, // sender
        PoolKey calldata key, // key
        IPoolManager.ModifyLiquidityParams calldata params, // params
        bytes calldata // data
    )
        external
        override
        returns (bytes4)
    {
        int24 currentTick = getCurrentTick(key);
        if(params.tickUpper > depegTick ){ //if price is below depeg threshold and token0 is being bought
            revert("Price is below depeg threshold");
        }

        return IHooks.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address, // sender
        PoolKey calldata, // key
        IPoolManager.ModifyLiquidityParams calldata, // params
        bytes calldata // data
    )
        external
        override
        returns (bytes4)
    {
        PoolKey memory key = _getPoolKey();
        uint256 currentPrice = calculatePrice(getCurrentPrice(key), getDecimals(key.currency0), getDecimals(key.currency1));
        if(currentPrice < depegThreshold){ //if price is below depeg threshold and token0 is being bought
            revert("Price is below depeg threshold");
        }

        return IHooks.beforeRemoveLiquidity.selector;
    }

    

    

    function beforeSwap(
        address, // sender
        PoolKey calldata, // key
        IPoolManager.SwapParams calldata params, // params
        bytes calldata // data
    )
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)

    {

        PoolKey memory key = _getPoolKey();
        uint256 currentPrice = calculatePrice(getCurrentPrice(key), getDecimals(key.currency0), getDecimals(key.currency1));
        if(currentPrice < depegThreshold && params.zeroForOne == true){ //if price is below depeg threshold and token0 is being bought
            revert("Price is below depeg threshold");
        }

        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    function getHookSwapFee(PoolKey calldata) external pure returns (uint8) {
        return 100;
    }

    function getHookWithdrawFee(PoolKey calldata) external pure returns (uint8) {
        return 100;
    }

    function getHookFees(PoolKey calldata key) external view returns (uint24){
        return 100;
    }

    function getFee(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data) external returns (uint24){
        return 10000;
    }

    /*
    function _storeUserPosition(address user, IPoolManager.ModifyLiquidityParams calldata params) internal{
        //get user liquidity
        int24 tickLower = params.tickLower;
        int24 tickUpper = params.tickUpper;

        PoolKey memory key = _getPoolKey();
        (uint160 sqrtPriceX96, int24 currentTick, ,  ) = poolManager.getSlot0(key.toId());
        uint128 userLiquidity = poolManager.getLiquidity(key.toId(),user,  tickLower, tickUpper);
        
        userPosition[user] = UserLiquidity(
            userLiquidity,
            tickLower,
            tickUpper
        );
        


    }
    */

    

    function getCurrentPrice(PoolKey memory poolKey) public view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
    }

    function calculatePrice(uint160 sqrtPriceX96, uint8 token0Decimals, uint8 token1Decimals) public pure returns (uint256) {
        uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * (10**token1Decimals) / (2**192) / (10**token0Decimals);
        return price;
    }

    function getCurrentTick(PoolKey memory poolKey) public view returns (int24 tick) {
        (, tick,,) = poolManager.getSlot0(poolKey.toId());
        return tick;
    }

    function tickToPrice(int24 tick, uint8 token0Decimals, uint8 token1Decimals) public pure returns (uint256) {
    uint256 price;
        if (tick >= 0) {
            price = uint256(1e18);
            for (int24 i = 0; i < tick; i++) {
                price = (price * 10001) / 10000;
            }
        } else {
            price = uint256(1e18);
            for (int24 i = tick; i < 0; i++) {
                price = (price * 10000) / 10001;
            }
        }

        // Adjust for decimal places
        if (tick >= 0) {
            return (price * 10 ** (token1Decimals + 18 - token0Decimals)) / 1e18;
        } else {
            return (10 ** (token0Decimals + 18 + token1Decimals)) / price;
        }
    }


    function getDecimals(Currency currency) public view returns (uint8) {
        if (currency.isNative()) {
            return 18; // ETH (or native currency) always has 18 decimals
        } else {
            address tokenAddress = Currency.unwrap(currency);
            return IERC20Metadata(tokenAddress).decimals();
        }
    }


    //Helper function to return PoolKey
    function _getPoolKey() private view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(FUSD)),
            currency1: Currency.wrap(address(USDC)),
            fee:  300, // 0xE00000 = 111 //todo change fee accordingly
            tickSpacing: 60,
            hooks: IHooks(address(this))
        });
    }
}