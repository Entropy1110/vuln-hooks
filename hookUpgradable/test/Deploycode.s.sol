// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
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
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";

import {ProxyContract} from "../src/ProxyContract.sol";
import {Implementation} from "../src/Implementation.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CounterTest is Script, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    PoolId poolId;
    address payable mockAddr;
    address payable hookAddr;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        manager = IPoolManager(0xE8E23e97Fa135823143d6b9Cba9c699040D51F70);

        Token0 token0 = new Token0();
        Token1 token1 = new Token1();
        
        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));



        bytes memory implBytecode = type(Implementation).creationCode;
        (address addr, bytes32 salt) = HookMiner.find(address(this), Hooks.ALL_HOOK_MASK, implBytecode, "");
        //create2 hookAddr
        assembly {
            addr := create2(0, add(implBytecode, 32), mload(implBytecode), salt)
        }
        hookAddr = payable(addr);


        bytes memory mockBytecode = type(ProxyContract).creationCode;
        (address addr2, bytes32 mockSalt) = HookMiner.find(address(this), Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG, mockBytecode, "");

        assembly {
            addr2 := create2(0, add(mockBytecode, 32), mload(mockBytecode), mockSalt)
        }
        mockAddr = payable(addr2);

        ProxyContract(mockAddr).setImplementation(hookAddr);

        
        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(mockAddr));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }
}

contract Token0 is ERC20 {
    constructor () ERC20("Token0", "TK0") {
        _mint(msg.sender, 1000000 * (10 ** uint(decimals())));
    }

}

contract Token1 is ERC20 {
    constructor () ERC20 ("Token1", "TK1") {
        _mint(msg.sender, 1000000 * (10 ** uint(decimals())));
    }
}