// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PoolTestBase} from "v4-core/src/test/PoolTestBase.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

contract CustomRouter is PoolTestBase {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using Hooks for IHooks;
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    constructor(IPoolManager _manager) PoolTestBase(_manager) {}

    struct SwapCallbackData {
        address sender;
        TestSettings testSettings;
        PoolKey key;
        IPoolManager.SwapParams params;
        bytes hookData;
    }

    struct LiquidityCallbackData {
        address sender;
        PoolKey key;
        IPoolManager.ModifyLiquidityParams params;
        bytes hookData;
        bool settleUsingBurn;
        bool takeClaims;
    }

    struct TestSettings {
        bool takeClaims;
        bool settleUsingBurn;
    }

    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes memory hookData
    ) external payable returns (BalanceDelta delta) {
        return swap(key, params, hookData, false, false);
    }

    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes memory hookData,
        bool settleUsingBurn,
        bool takeClaims
    ) public payable returns (BalanceDelta delta) {
        bytes memory newHookData = abi.encode(msg.sender, hookData);
        SwapCallbackData memory callbackData = SwapCallbackData(
            msg.sender,
            TestSettings(settleUsingBurn, takeClaims),
            key,
            params,
            newHookData
        );
        delta = abi.decode(
            manager.unlock(abi.encode(bytes32("swap"), callbackData)),
            (BalanceDelta)
        );

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
    }

    function modifyLiquidity(
        PoolKey memory key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes memory hookData
    ) external payable returns (BalanceDelta delta) {
        return modifyLiquidity(key, params, hookData, false, false);
    }

    function modifyLiquidity(
        PoolKey memory key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes memory hookData,
        bool settleUsingBurn,
        bool takeClaims
    ) public payable returns (BalanceDelta delta) {
        bytes memory newHookData = abi.encode(msg.sender, hookData);
        LiquidityCallbackData memory callbackData = LiquidityCallbackData(
            msg.sender,
            key,
            params,
            newHookData,
            settleUsingBurn,
            takeClaims
        );
        delta = abi.decode(
            manager.unlock(abi.encode(bytes32("modifyLiquidity"), callbackData)),
            (BalanceDelta)
        );

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
    }

     function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
            require(msg.sender == address(manager), "Only manager can call");

            (bytes32 action, bytes memory data) = abi.decode(rawData, (bytes32, bytes));

            if (action == bytes32("swap")) {
                SwapCallbackData memory swapData = abi.decode(data, (SwapCallbackData));
                return handleSwapCallback(swapData);
            } else if (action == bytes32("modifyLiquidity")) {
                LiquidityCallbackData memory liquidityData = abi.decode(data, (LiquidityCallbackData));
                return handleLiquidityCallback(liquidityData);
            } else {
                revert("Invalid action");
            }
}

    function handleSwapCallback(SwapCallbackData memory data) internal returns (bytes memory) {
        (,, int256 deltaBefore0) = _fetchBalances(data.key.currency0, data.sender, address(this));
        (,, int256 deltaBefore1) = _fetchBalances(data.key.currency1, data.sender, address(this));

        require(deltaBefore0 == 0, "deltaBefore0 is not equal to 0");
        require(deltaBefore1 == 0, "deltaBefore1 is not equal to 0");

        BalanceDelta delta = manager.swap(data.key, data.params, data.hookData);

        (,, int256 deltaAfter0) = _fetchBalances(data.key.currency0, data.sender, address(this));
        (,, int256 deltaAfter1) = _fetchBalances(data.key.currency1, data.sender, address(this));

        if (deltaAfter0 < 0) {
            data.key.currency0.settle(manager, data.sender, uint256(-deltaAfter0), data.testSettings.settleUsingBurn);
        }
        if (deltaAfter1 < 0) {
            data.key.currency1.settle(manager, data.sender, uint256(-deltaAfter1), data.testSettings.settleUsingBurn);
        }
        if (deltaAfter0 > 0) {
            data.key.currency0.take(manager, data.sender, uint256(deltaAfter0), data.testSettings.takeClaims);
        }
        if (deltaAfter1 > 0)  {
            data.key.currency1.take(manager, data.sender, uint256(deltaAfter1), data.testSettings.takeClaims);
        }

        return abi.encode(delta);
    }

    function handleLiquidityCallback(LiquidityCallbackData memory data) internal returns (bytes memory) {
        (uint128 liquidityBefore, ,) = manager.getPositionInfo(
            data.key.toId(), address(this), data.params.tickLower, data.params.tickUpper, data.params.salt
        );

        (BalanceDelta delta,) = manager.modifyLiquidity(data.key, data.params, data.hookData);

        (uint128 liquidityAfter, ,) = manager.getPositionInfo(
            data.key.toId(), address(this), data.params.tickLower, data.params.tickUpper, data.params.salt
        );

        (,, int256 delta0) = _fetchBalances(data.key.currency0, data.sender, address(this));
        (,, int256 delta1) = _fetchBalances(data.key.currency1, data.sender, address(this));

        require(
            int128(liquidityBefore) + data.params.liquidityDelta == int128(liquidityAfter),
            "liquidity change incorrect"
        );

        if (delta0 < 0) data.key.currency0.settle(manager, data.sender, uint256(-delta0), data.settleUsingBurn);
        if (delta1 < 0) data.key.currency1.settle(manager, data.sender, uint256(-delta1), data.settleUsingBurn);
        if (delta0 > 0) data.key.currency0.take(manager, data.sender, uint256(delta0), data.takeClaims);
        if (delta1 > 0) data.key.currency1.take(manager, data.sender, uint256(delta1), data.takeClaims);

        return abi.encode(delta);
    }

    receive() external payable {}
}
