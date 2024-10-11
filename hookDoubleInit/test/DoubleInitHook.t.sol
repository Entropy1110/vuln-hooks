// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Constants} from "v4-core/../test/utils/Constants.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import "forge-std/Test.sol";

contract DoubleInitHookTest is Test {
    address public hookAddr;
    Currency currency0;
    Currency currency1;
    IPoolManager manager = IPoolManager(0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);
    PoolKey key;

    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;
    uint160 constant SQRT_PRICE_1_1 = Constants.SQRT_PRICE_1_1;

    function test_double_init() public {
        string memory code_json = vm.readFile("test/PoolKey.json");
        address _currency0 = vm.parseJsonAddress(code_json, ".data.currency0");
        address _currency1 = vm.parseJsonAddress(code_json, ".data.currency1");
        uint24 _fee = uint24(vm.parseJsonUint(code_json, ".data.fee"));
        int24 _tickSpacing = int24(vm.parseJsonInt(code_json, ".data.tickSpacing"));
        hookAddr = vm.parseJsonAddress(code_json, ".data.hooks");
        currency0 = Currency.wrap(_currency0);
        currency1 = Currency.wrap(_currency1);

        key = PoolKey(currency0, currency1, 1000, 60, IHooks(hookAddr));

        try manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES)
        {
            revert("Double initialization must be failed");
        }catch {
            
        }

    }
}
