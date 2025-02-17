import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {AbsFedzPoolWrapper} from "./AbsFedzPoolWrapper.sol";
import {IFedzModifyLiquidityWrapper} from "./interfaces/IFedzModifyLiquidityWrapper.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";

contract FedzModifyLiquidityWrapper is IFedzModifyLiquidityWrapper, AbsFedzPoolWrapper, SafeCallback {


    constructor(address _TheFedzHook, uint24 _swapFee, int24 tickSpacing, address _poolManager) 
        AbsFedzPoolWrapper(_TheFedzHook, _swapFee, tickSpacing)
        SafeCallback(IPoolManager(_poolManager))
    {}

    function modifiyLiquidity(FedzModifyLiquidityParams memory params) external returns(BalanceDelta delta, BalanceDelta feeDelta) {
        bytes memory callbackData = abi.encode(msg.sender, params);
        bytes memory results = IPoolManager(address(poolManager)).unlock(callbackData);
        return abi.decode(results, (BalanceDelta, BalanceDelta));
    }

    function _unlockCallback(bytes calldata data) internal override returns(bytes memory results) {

        (address player
        , FedzModifyLiquidityParams memory params
        ) = abi.decode(data, (address, FedzModifyLiquidityParams));

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(params.token0),
            currency1: Currency.wrap(params.token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(TheFedzHook)
        });

        IPoolManager.ModifyLiquidityParams memory modifyLiquidityParams = IPoolManager.ModifyLiquidityParams({
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidityDelta: params.liquidityDelta,
            salt: bytes32(uint256(uint160(player)))
        });

        bytes memory hookData = abi.encode(player);
        (BalanceDelta delta, BalanceDelta feeDelta) = IPoolManager(poolManager).modifyLiquidity(pool, modifyLiquidityParams, hookData);
        results = abi.encode(delta, feeDelta);
        _closeDelta(player, params.token0, params.token1, delta, pool);
    }
}