import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

interface IFedzHook is IHooks {

    event DepegThresholdUpdated(uint256 newThreshold);
    event CrisisStateChanged(bool isInCrisis);
    event LiquidityAdded(address user, uint128 amount);
    event LiquidityRemoved(address user, uint128 amount);
    event BeforeSwapExecuted(address user, bool zeroForOne, int256 amountIn);

    event AfterSwapExecuted(address user, bool zeroForOne, int256 amountIn);
    event RewardClaimed(address user, uint256 amount);
    event LiquidityAdded(address indexed sender, uint128 liquidity, int24 tickLower, int24 tickUpper);
    event LiquidityRemoved(address indexed sender, uint128 liquidity, int24 tickLower, int24 tickUpper);
    event FeesUpdated(uint24 baseFee, uint24 crisisFee);

    event PriceIs(uint256 price); //Test only

    error NotCustomRouter(address router);
    error NotPlayerTurn(address sender);

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata data
    ) external override returns (bytes4);

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata data
    ) external view returns (bytes4);

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata data
    ) external override returns (bytes4);

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) external override returns (bytes4, BeforeSwapDelta, uint24);

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata data
    ) external override returns (bytes4, int128);
}