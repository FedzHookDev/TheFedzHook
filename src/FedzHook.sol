// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IFedzHook} from "./interfaces/IFedzHook.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FedzHook is IFedzHook, BaseHook, Ownable  {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 public removalPriceThreshold = 79228162514264337593543;   //    1USDT / 1FUSD
    uint256 public depegThreshold = 75162434512514379355924;          //    9USDT / 10FUSD
    ITimeSlotSystem public timeSlotSystem;

    constructor(
        IPoolManager _poolManager,
        address _owner,
        address _timeSlotSystem
    ) BaseHook(_poolManager) Ownable(_owner) {
        timeSlotSystem = ITimeSlotSystem(_timeSlotSystem);
    }

    modifier onlyActingPlayer() {
        address player = tx.origin;
        address actingPlayer = timeSlotSystem.getCurrentPlayer();
        if (actingPlayer != player) {
            revert NotActingPlayer(player, actingPlayer);
        }
        _;
    }

    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata data
    )
        onlyActingPlayer
        internal
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function _beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata data
    )
        onlyActingPlayer
        internal
        override
        returns (bytes4)
    {
        uint160 sqrtPriceX96 = getCurrentPrice(key);
        if (sqrtPriceX96 < removalPriceThreshold) {
            revert PriceIsTooLowToRemoveLiquidity(removalPriceThreshold, sqrtPriceX96);
        }
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    )
        onlyActingPlayer
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), key.fee);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata data
    )
        internal
        override
        returns (bytes4, int128)
    {
        uint160 sqrtPriceX96 = getCurrentPrice(key);
        if (sqrtPriceX96 < depegThreshold) {
            revert SwapResultsTooLowPrice(depegThreshold, sqrtPriceX96);
        }
        return (IHooks.afterSwap.selector, 0);
    }

    function getCurrentPrice(PoolKey memory poolKey) internal view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
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
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    ////////////////////////////////////////////////////
    ///// Admin functions
    ////////////////////////////////////////////////////
    function setDepegThreshold(uint256 _depegThreshold) external onlyOwner {
        depegThreshold = _depegThreshold;
        emit DepegThresholdUpdated(_depegThreshold);
    }

    function setRemovalPriceThreshold(uint256 _removalPriceThreshold) external onlyOwner {
        removalPriceThreshold = _removalPriceThreshold;
        emit RemovalPriceThresholdUpdated(_removalPriceThreshold);
    }

    function setTimeSlotSystem(address _timeSlotSystem) external onlyOwner {
        timeSlotSystem = ITimeSlotSystem(_timeSlotSystem);
        emit TimeSlotSystemUpdated(_timeSlotSystem);
    }
}