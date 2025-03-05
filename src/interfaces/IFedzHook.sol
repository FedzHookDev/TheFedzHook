import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

interface IFedzHook is IHooks {

    event DepegThresholdUpdated(uint256 newThreshold);
    event RemovalPriceThresholdUpdated(uint256 newThreshold);
    event TimeSlotSystemUpdated(address newTimeSlotSystem);

    error NotActingPlayer(address sender, address actualPlayer);
    error PriceIsTooLowToRemoveLiquidity(uint256 removalPriceThreshold, uint256 currentPrice);
    error SwapResultsTooLowPrice(uint256 depegThreshold, uint256 currentPrice);
}