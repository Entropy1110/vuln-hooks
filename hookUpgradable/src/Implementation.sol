// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

contract Implementation is IHooks {
    using Hooks for IHooks;

    constructor() {
        IHooks(this).validateHookPermissions(
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: true,
                beforeAddLiquidity: true,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: true,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: true,
                afterDonate: true,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: true,
                afterRemoveLiquidityReturnDelta: true
            })
        );
    }

    function beforeInitialize(address, PoolKey calldata, uint160, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        override
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }
}
