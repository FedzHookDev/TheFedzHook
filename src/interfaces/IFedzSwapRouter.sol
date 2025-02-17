import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

interface IFedzSwapRouter {

    function swap(address token0, address token1, IPoolManager.SwapParams memory params) external  returns(BalanceDelta delta);

    // function unlockCallback(bytes memory data) external returns(bytes memory results);
}