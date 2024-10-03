// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Foundry libraries
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";

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
import {TakeProfitsHook} from "../src/TakeProfitsHook.sol";

contract TakeProfitsHookTest is Test, Deployers {
    // Use the libraries
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;

    TakeProfitsHook hook;

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();

        // Deploy two test tokens
        (token0, token1) = deployMintAndApprove2Currencies();

        // Deploy our hook
        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags); //원래 적용된 hook의 flag에 따라 address mining을 수행해야함. deploy script 따로 존재.
        deployCodeTo("TakeProfitsHook.sol", abi.encode(manager, ""), hookAddress); // 임의로 flag만 적용된 주소에 hook deploy
        hook = TakeProfitsHook(hookAddress);

        // Approve our hook address to spend these tokens as well
        MockERC20(Currency.unwrap(token0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(token1)).approve(address(hook), type(uint256).max);

        // Initialize a pool with these two tokens
        (key,) = initPool(token0, token1, hook, 3000, SQRT_PRICE_1_1, ZERO_BYTES);

        // Add initial liquidity to the pool

        // Some liquidity from -60 to +60 tick range
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        // Some liquidity from -120 to +120 tick range
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -120,
                tickUpper: 120,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        // some liquidity for full range
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(60),
                tickUpper: TickMath.maxUsableTick(60),
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }


    function testFail_orderExecute_zeroForOne() public {
        int24 tick = 100;
        uint256 amount = 1 ether;
        bool zeroForOne = true;

        // Place our order at tick 100 for 10e18 token0 tokens
        int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);

        // Do a separate swap from oneForZero to make tick go up
        // Sell 1e18 token1 tokens for token0 tokens
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: !zeroForOne,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        // Conduct the swap - `afterSwap` should also execute our placed order
        swapRouter.swap(key, params, testSettings, ZERO_BYTES);

        // Check that the order has been executed
        // by ensuring no amount is left to sell in the pending orders
        uint256 pendingTokensForPosition = hook.pendingOrders(key.toId(), tick, zeroForOne);
        assertEq(pendingTokensForPosition, 0);

        // Check that the hook contract has the expected number of token1 tokens ready to redeem
        uint256 positionId = hook.getPositionId(key, tickLower, zeroForOne); //position id 계산
        uint256 claimableOutputTokens = hook.claimableOutputTokens(positionId); //claim 가능한 토큰1의 양 계산
        uint256 hookContractToken1Balance = token1.balanceOf(address(hook));
        assertEq(claimableOutputTokens, hookContractToken1Balance); // hook contract의 token1의 양과 비교 -> 동일

        // Ensure we can redeem the token1 tokens
        uint256 originalToken1Balance = token1.balanceOf(address(this));
        hook.redeem(key, tick, zeroForOne, amount); // output token을 얻기 위해 redeem 호출
        uint256 newToken1Balance = token1.balanceOf(address(this));

        assertEq(newToken1Balance - originalToken1Balance, claimableOutputTokens);
    }

    function testFail_orderExecute_oneForZero() public {
        int24 tick = -100;
        uint256 amount = 10 ether;
        bool zeroForOne = false;

        // Place our order at tick -100 for 10e18 token1 tokens
        int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);

        // Do a separate swap from zeroForOne to make tick go down
        // Sell 1e18 token0 tokens for token1 tokens
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        swapRouter.swap(key, params, testSettings, ZERO_BYTES);

        // Check that the order has been executed
        uint256 tokensLeftToSell = hook.pendingOrders(key.toId(), tick, zeroForOne);
        assertEq(tokensLeftToSell, 0);

        // Check that the hook contract has the expected number of token0 tokens ready to redeem
        uint256 positionId = hook.getPositionId(key, tickLower, zeroForOne);
        uint256 claimableOutputTokens = hook.claimableOutputTokens(positionId);
        uint256 hookContractToken0Balance = token0.balanceOf(address(hook));
        assertEq(claimableOutputTokens, hookContractToken0Balance);

        // Ensure we can redeem the token0 tokens
        uint256 originalToken0Balance = token0.balanceOfSelf();
        hook.redeem(key, tick, zeroForOne, amount);
        uint256 newToken0Balance = token0.balanceOfSelf();

        assertEq(newToken0Balance - originalToken0Balance, claimableOutputTokens);
    }

}
