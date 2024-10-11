// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import {HookMiner} from "./HookMiner.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Constants} from "v4-core/../test/utils/Constants.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import "forge-std/Script.sol";


import {ExampleHook} from "../src/ExampleHook.sol";

contract ExampleHookDeployer is Script {

    address public hookAddr;
    address public deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    Currency currency0 = Currency.wrap(address(0x0000000000000000000000000000000000000000));
    Currency currency1 = Currency.wrap(address(0x6f0cD9aC99c852bDBA06F72db93078cbA80A32F5));
    IPoolManager manager = IPoolManager(0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);
    PoolKey key;

    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;
    uint160 constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;

    function run() public {
        vm.startBroadcast();

        bytes memory implBytecode = type(ExampleHook).creationCode;
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        (address addr, uint hookSalt) = HookMiner.find(address(deployer), flags, implBytecode, abi.encode(address(manager)));
        addr = address(new ExampleHook{salt: bytes32(hookSalt)}(IPoolManager(address(manager))));
        hookAddr = payable(addr);

        console.log("hookAddr : ", hookAddr);

        key = PoolKey(currency0, currency1, 0, 60, IHooks(hookAddr));

        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);
    }

}
