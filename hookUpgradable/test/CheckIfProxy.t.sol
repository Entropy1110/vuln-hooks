// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";

import {ProxyContract} from "../src/ProxyContract.sol";
import {Implementation} from "../src/Implementation.sol";

contract CounterTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    address public hookAddr;
    Currency currency0;
    Currency currency1;
    IPoolManager manager = IPoolManager(0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);
    PoolKey key;
    PoolId poolId;
    address payable mockAddr;
    address payable hookAddr;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;


    function test_if_proxy() public {
        //get slot 0 value of the proxy contract
        bytes32 slot0 = vm.load(mockAddr, 0);
        address couldBeImplementation = address(uint160(uint(slot0)));
        if (couldBeImplementation != address(0)) {
            bool isImplementation = couldBeImplementation.code.length > 0;
            assertFalse(isImplementation, "Hook might be a proxy");
        }
    }
}
