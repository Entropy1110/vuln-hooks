// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";

contract DoubleInitHook is BaseHook {

    address public hookOperator;
    uint256 public maxSwapCounter;
    mapping (PoolId => uint256) public swapCounter;

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(
        address sender, /* sender **/
        PoolKey calldata, /* key **/
        uint160, /* sqrtPriceX96 **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4) {
        require(hookOperator == address(0), "DoubleInitHook: already initialized");
        hookOperator = sender;
        return this.beforeInitialize.selector;
    }

    function beforeSwap(
        address, /* sender **/
        PoolKey calldata key, /* key **/
        IPoolManager.SwapParams calldata, /* params **/
        bytes calldata /* hookData **/
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        swapCounter[key.toId()] += 1;
        if (swapCounter[key.toId()] > maxSwapCounter) {
            maxSwapCounter = swapCounter[key.toId()];
        }
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }


    function withdrawAll() external payable{
        require(msg.sender == hookOperator, "DoubleInitHook: not operator");
        (bool success, ) = payable(hookOperator).call{value : address(this).balance}("");
        require(success, "DoubleInitHook: withdraw failed");
    }

    receive() external payable {}

}
