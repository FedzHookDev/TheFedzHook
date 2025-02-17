import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {AbsFedzPoolWrapper} from "./AbsFedzPoolWrapper.sol";
import {IFedzSwapRouter} from "./interfaces/IFedzSwapRouter.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";

contract FedzSwapRouter is IFedzSwapRouter, AbsFedzPoolWrapper, SafeCallback {

    constructor(address _TheFedzHook, uint24 _swapFee, int24 tickSpacing, address _poolManager) 
        AbsFedzPoolWrapper(_TheFedzHook, _swapFee, tickSpacing)
        SafeCallback(IPoolManager(_poolManager))
    {}

    function swap(address token0, address token1, IPoolManager.SwapParams memory params) external returns(BalanceDelta delta) {
        bytes memory callbackData = abi.encode(msg.sender, token0, token1, params);
        bytes memory results = IPoolManager(address(poolManager)).unlock(callbackData);
        delta = abi.decode(results, (BalanceDelta));
    }

    function _unlockCallback(bytes calldata data) internal override returns(bytes memory results) {
        (address player
        , address token0
        , address token1
        , IPoolManager.SwapParams memory params
        ) = abi.decode(data, (address, address, address, IPoolManager.SwapParams));

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(TheFedzHook)
        });

        BalanceDelta delta = IPoolManager(poolManager).swap(pool, params, data);
        results = abi.encode(delta);
        _closeDelta(player, token0, token1, delta, pool);
    }
}