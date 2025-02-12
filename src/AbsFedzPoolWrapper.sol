import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

abstract contract AbsFedzPoolWrapper {

    address immutable poolManager;
    address immutable TheFedzHook;
    uint24 immutable swapFee; // set 4000 for 0.40% fee tier
    int24 immutable tickSpacing;

    error NotPoolManager();

    constructor(address _TheFedzHook, uint24 _swapFee, int24 _tickSpacing, address _poolManager) {
        TheFedzHook = _TheFedzHook;
        swapFee = _swapFee;
        tickSpacing = _tickSpacing;
        poolManager = _poolManager;
    }

    modifier onlyPoolManager() {
        if (msg.sender != poolManager) revert NotPoolManager();
        _;
    }

    function _closeDelta(address player, address token0, address token1, BalanceDelta delta, PoolKey memory pool) internal {
        if (delta.amount0() < 0) {
            uint256 amount0 = uint256(uint128(-delta.amount0()));
            IERC20(token0).transferFrom(player, address(this), amount0);
            IPoolManager(msg.sender).sync(pool.currency0);
            pool.currency0.transfer(msg.sender, amount0);
            IPoolManager(msg.sender).settleFor(address(this));
        } else if (delta.amount0() > 0) {
            uint256 amount0 = uint256(uint128(delta.amount0()));
            IPoolManager(msg.sender).take(pool.currency0, player, amount0);
        }
        if (delta.amount1() < 0) {
            uint256 amount1 = uint256(uint128(-delta.amount1()));
            IERC20(token1).transferFrom(player, address(this), amount1);
            IPoolManager(msg.sender).sync(pool.currency1);
            pool.currency1.transfer(msg.sender, amount1);
            IPoolManager(msg.sender).settleFor(address(this));
        } else if (delta.amount1() > 0) {
            uint256 amount1 = uint256(uint128(delta.amount1()));
            IPoolManager(msg.sender).take(pool.currency1, player, amount1);
        }
    }
}