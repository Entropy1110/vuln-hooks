// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Foundry libraries
import "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

// Our contracts
import {MaliciousHook} from "../src/MaliciousHook.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

contract TakeProfitsHookTest is Test, Deployers {
    // Use the libraries
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;

    MaliciousHook hook;
    address alice;

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();
        alice = tx.origin;
        

        // Deploy two test tokens
        (token0, token1) = deployMintAndApprove2Currencies();
        token0.transfer(address(manager), 1000 ether);
        token1.transfer(address(manager), 1000 ether);

        token0.transfer(alice, 3000 ether);
        token1.transfer(alice, 3000 ether);
        vm.label(Currency.unwrap(token0), "token0");
        vm.label(Currency.unwrap(token1), "token1");


        // Deploy our hook
        uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG);
        address hookAddress = address(flags); //원래 적용된 hook의 flag에 따라 address mining을 수행해야함. deploy script 따로 존재.
        deployCodeTo("MaliciousHook.sol", abi.encode(manager), hookAddress); // 임의로 flag만 적용된 주소에 hook deploy
        hook = MaliciousHook(hookAddress);

        // Approve our hook address to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(hook), type(uint256).max);

        vm.startPrank(alice);
        MockERC20(Currency.unwrap(token0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(token0)).approve(address(manager), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(manager), type(uint256).max);
        MockERC20(Currency.unwrap(token0)).approve(address(modifyLiquidityRouter), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(modifyLiquidityRouter), type(uint256).max);
        MockERC20(Currency.unwrap(token0)).approve(address(swapRouter), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();

        // Initialize a pool with these two tokens
        (key,) = initPool(token0, token1, hook, 0, 60, SQRT_PRICE_1_1, ZERO_BYTES);


        // Add initial liquidity to the pool
        originalAddLiquidity();
        // test_stealWhileRemoveLiquidity();
    }

    function test_stealWhileAddLiquidity() public {
        // Some liquidity from -60 to +60 tick range
        vm.startPrank(alice);
        uint a = token0.balanceOf(alice);
        uint c = token1.balanceOf(alice);
        IPoolManager.ModifyLiquidityParams memory modifyLiquidityParams =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32(new bytes(1))});
        BalanceDelta bd = modifyLiquidityRouter.modifyLiquidity(key,modifyLiquidityParams, abi.encode(alice));
        uint b = token0.balanceOf(alice);
        uint d = token1.balanceOf(alice);
        console.log("test_stealWhileAddLiquidity_hook_token0", token0.balanceOf(address(hook)));
        console.log("test_stealWhileAddLiquidity_hook_token1", token1.balanceOf(address(hook)));
        console.log("test_stealWhileAddLiquidity_my_token0", token0.balanceOf(alice));
        console.log("test_stealWhileAddLiquidity_my_token1", token1.balanceOf(alice));
        vm.stopPrank();
    }

    function test_stealWhileRemoveLiquidity() public {
        // Some liquidity from -60 to +60 tick range
        vm.startPrank(alice);
        uint a = token0.balanceOf(alice);
        uint c = token1.balanceOf(alice);
        IPoolManager.ModifyLiquidityParams memory modifyLiquidityParams =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: -1e18, salt: bytes32(new bytes(0))});
        BalanceDelta bd = modifyLiquidityRouter.modifyLiquidity(key,modifyLiquidityParams, "");
        uint b = token0.balanceOf(alice);
        uint d = token1.balanceOf(alice);
        console.log("test_stealWhileRemoveLiquidity_hook_token0", token0.balanceOf(address(hook)));
        console.log("test_stealWhileRemoveLiquidity_hook_token1", token1.balanceOf(address(hook)));
        console.log("test_stealWhileRemoveLiquidity_my_token0", token0.balanceOf(alice));
        console.log("test_stealWhileRemoveLiquidity_my_token1", token1.balanceOf(alice));
        vm.stopPrank();
    }

    function test_stealWhileSwap() public {
        vm.startPrank(alice);
        uint a = token0.balanceOf(alice);
        uint c = token1.balanceOf(alice);

        uint256 amountToSwap = 1000;
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(amountToSwap),
            sqrtPriceLimitX96: MAX_PRICE_LIMIT
        });
        BalanceDelta bd = swapRouter.swap(key, params, testSettings, abi.encode(alice));

        uint b = token0.balanceOf(alice);
        uint d = token1.balanceOf(alice);
        console.log("test_stealWhileSwap_hook_token0", token0.balanceOf(address(hook)));
        console.log("test_stealWhileSwap_hook_token1", token1.balanceOf(address(hook)));
        console.log("test_stealWhileSwap_my_token0", token0.balanceOf(alice));
        console.log("test_stealWhileSwap_my_token1", token1.balanceOf(alice));
        vm.stopPrank();
    }

    function originalSwap() internal {
        vm.startPrank(alice);
        console.log("my_token0", token0.balanceOf(alice));
        console.log("my_token1", token0.balanceOf(alice));
        uint256 amountToSwap = 1000;
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(amountToSwap),
            sqrtPriceLimitX96: MAX_PRICE_LIMIT
        });
        BalanceDelta bd = swapRouter.swap(key, params, testSettings, "");
        vm.stopPrank();
    }

    function originalAddLiquidity() internal {
        vm.startPrank(alice);
        console.log("my_token0", token0.balanceOf(alice));
        console.log("my_token1", token0.balanceOf(alice));
        IPoolManager.ModifyLiquidityParams memory modifyLiquidityParams =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: bytes32(new bytes(1))});
        BalanceDelta bd = modifyLiquidityRouter.modifyLiquidity(key,modifyLiquidityParams, "");
        vm.stopPrank();
    }
}