// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract ExampleHook is BaseHook {
    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
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

    function beforeInitialize(
        address, /* sender **/
        PoolKey calldata, /* key **/
        uint160, /* sqrtPriceX96 **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.beforeInitialize.selector;
    }

    function afterInitialize(
        address, /* sender **/
        PoolKey calldata, /* key **/
        uint160, /* sqrtPriceX96 **/
        int24, /* tick **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        BalanceDelta, /* delta **/
        BalanceDelta, /* feeDelta **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4, BalanceDelta) {
        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeRemoveLiquidity(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        BalanceDelta, /* delta **/
        BalanceDelta, /* feeDelta **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4, BalanceDelta) {
        return (this.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function beforeSwap(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.SwapParams calldata, /* params **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address, /* sender **/
        PoolKey calldata, /* key **/
        IPoolManager.SwapParams calldata, /* params **/
        BalanceDelta, /* delta **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4, int128) {
        return (this.afterSwap.selector, 0);
    }

    function beforeDonate(
        address, /* sender **/
        PoolKey calldata, /* key **/
        uint256, /* amount0 **/
        uint256, /* amount1 **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.beforeDonate.selector;
    }

    function afterDonate(
        address, /* sender **/
        PoolKey calldata, /* key **/
        uint256, /* amount0 **/
        uint256, /* amount1 **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        return this.afterDonate.selector;
    }
}
