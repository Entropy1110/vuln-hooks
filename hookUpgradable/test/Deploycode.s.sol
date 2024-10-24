// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

import {ProxyContract} from "../src/ProxyContract.sol";
import {Implementation} from "../src/Implementation.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CounterTest is Script {
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    bytes constant ZERO_BYTES = new bytes(0);

    PoolId poolId;
    address payable mockAddr;
    address payable hookAddr;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    Currency currency0;
    Currency currency1;

    PoolKey key;
    IPoolManager manager;


    function run() public {
        vm.startBroadcast();
        // creates the pool manager, utility routers, and test tokens
        manager = IPoolManager(0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);
        address deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        Token0 token0 = Token0(0x0000000000000000000000000000000000000000);
        Token1 token1 = Token1(0x6f0cD9aC99c852bDBA06F72db93078cbA80A32F5);
        
        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));



        bytes memory implBytecode = type(Implementation).creationCode;
        (address addr, bytes32 salt) = HookMiner.find(deployer, Hooks.ALL_HOOK_MASK, implBytecode, "");
        //create2 hookAddr
        // assembly {
        //     addr := create2(0, add(implBytecode, 32), mload(implBytecode), salt)
        // }
        addr = address(new Implementation{salt : salt}());
        hookAddr = payable(addr);


        bytes memory mockBytecode = type(ProxyContract).creationCode;
        (address addr2, bytes32 mockSalt) = HookMiner.find(deployer, Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG, mockBytecode, "");

        // assembly {
        //     addr2 := create2(0, add(mockBytecode, 32), mload(mockBytecode), mockSalt)
        // }

        addr2 = address(new ProxyContract{salt : mockSalt}());
        mockAddr = payable(addr2);

        ProxyContract(mockAddr).setImplementation(hookAddr);

        
        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(mockAddr));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, "");

        // // Provide full-range liquidity to the pool
        // tickLower = TickMath.minUsableTick(key.tickSpacing);
        // tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        // uint128 liquidityAmount = 100e18;

        // (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
        //     SQRT_PRICE_1_1,
        //     TickMath.getSqrtPriceAtTick(tickLower),
        //     TickMath.getSqrtPriceAtTick(tickUpper),
        //     liquidityAmount
        // );

        console.log("Hook Address: ", hookAddr);
        console.log("Proxy Address: ", mockAddr);
        console.log("Token0 Address: ", address(token0));
        console.log("Token1 Address: ", address(token1));



    }
}

contract Token0 is ERC20 {
    constructor () ERC20("Token0", "TK0") {
        _mint(msg.sender, 1000000 * (10 ** uint(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}

contract Token1 is ERC20 {
    constructor () ERC20 ("Token1", "TK1") {
        _mint(msg.sender, 1000000 * (10 ** uint(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}