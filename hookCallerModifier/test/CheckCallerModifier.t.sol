// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {HookCallerModifier} from "../src/HookCallerModifier.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";

contract CounterTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    error NotPoolManager();

    HookCallerModifier hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;


    Hooks.Permissions perms;
    bool zeroForOne = true;
    IPoolManager.SwapParams params = IPoolManager.SwapParams({
        zeroForOne: true,
        amountSpecified: -0.00001 ether,
        sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    });

    BalanceDelta balanceDelta = toBalanceDelta(0, 0);

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);


        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("HookCallerModifier.sol:HookCallerModifier", constructorArgs, flags);
        hook = HookCallerModifier(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
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

        hook = HookCallerModifier(0xce12A4E8980a70B0f4Bf16d89dD734dDb507Cac0);

        perms = hook.getHookPermissions();
 
    }

    function test_beforeRemoveLiquidity() public {
        if (perms.beforeRemoveLiquidity) {
            try hook.beforeRemoveLiquidity(address(this), key, 
                IPoolManager.ModifyLiquidityParams({
                    tickLower: -60,
                    tickUpper: 60,
                    liquidityDelta: 0 ether,
                    salt: bytes32(0)
                }), ZERO_BYTES) {
                revert("Expected NotPoolManager : beforeRemoveLiquidity must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_afterRemoveLiquidity() public {
        if (perms.afterRemoveLiquidity) {
            
            try hook.afterRemoveLiquidity(address(this), key, 
                IPoolManager.ModifyLiquidityParams({
                    tickLower: -60,
                    tickUpper: 60,
                    liquidityDelta: 0 ether,
                    salt: bytes32(0)
                }),balanceDelta,balanceDelta, ZERO_BYTES) {
                revert("Expected NotPoolManager : afterRemoveLiquidity must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_beforeAddLiquidity() public {
        if (perms.beforeAddLiquidity) {
            try hook.beforeAddLiquidity(address(this), key, 
                IPoolManager.ModifyLiquidityParams({
                    tickLower: -60,
                    tickUpper: 60,
                    liquidityDelta: 0 ether,
                    salt: bytes32(0)
                }), ZERO_BYTES) {
                revert("Expected NotPoolManager : beforeAddLiquidity must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_afterAddLiquidity() public {
        if (perms.afterAddLiquidity) {
            try hook.afterAddLiquidity(address(this), key, 
                IPoolManager.ModifyLiquidityParams({
                    tickLower: -60,
                    tickUpper: 60,
                    liquidityDelta: 0 ether,
                    salt: bytes32(0)
                }),balanceDelta,balanceDelta, ZERO_BYTES) {
                revert("Expected NotPoolManager : afterAddLiquidity must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_beforeSwap() public {
        if (perms.beforeSwap) {
            try hook.beforeSwap(address(this), key, params, ZERO_BYTES) {
                revert("Expected NotPoolManager : beforeSwap must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_afterSwap() public {
        if (perms.afterSwap) {
            try hook.afterSwap(address(this), key, params, toBalanceDelta(0, 0), ZERO_BYTES) {
                revert("Expected NotPoolManager : afterSwap must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_afterInitialize() public {
        if (perms.afterInitialize) {
            try hook.afterInitialize(address(this), key, SQRT_PRICE_1_1, 0, ZERO_BYTES) {
                revert("Expected NotPoolManager : afterInitialize must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_beforeInitialize() public {
        if (perms.beforeInitialize) {
            try hook.beforeInitialize(address(this), key, SQRT_PRICE_1_1, ZERO_BYTES) {
                revert("Expected NotPoolManager : beforeInitialize must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_beforeDonate() public {
        if (perms.beforeDonate) {
            try hook.beforeDonate(address(this), key, 0, 0, ZERO_BYTES) {
                revert("Expected NotPoolManager : beforeDonate must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    function test_afterDonate() public {
        if (perms.afterDonate) {
            try hook.afterDonate(address(this), key, 0, 0, ZERO_BYTES) {
                revert("Expected NotPoolManager : afterDonate must be called by PoolManager");
            } catch  {
                // assertEq(reason, "NotPoolManager");
            }
        }
    }

    
}