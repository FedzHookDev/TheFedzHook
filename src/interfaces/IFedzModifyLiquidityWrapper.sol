
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

interface IFedzModifyLiquidityWrapper {

    struct FedzModifyLiquidityParams {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // how to modify the liquidity
        int256 liquidityDelta;
    }

    function modifiyLiquidity(FedzModifyLiquidityParams memory params) external returns(BalanceDelta delta, BalanceDelta feeDelta);

    function unlockCallback(bytes memory data) external returns(bytes memory results);
}