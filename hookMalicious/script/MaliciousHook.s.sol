// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

// Our contracts
import {MaliciousHook} from "../src/MaliciousHook.sol";
import {HookMiner} from "./HookMiner.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";

import "forge-std/Script.sol";

contract Token0 is ERC20 {
    constructor() ERC20("Token0", "USDC") {
        _mint(tx.origin, 1000000 * (10 ** uint256(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract Token1 is ERC20 {
    constructor() ERC20("Token1", "UNI") {
        _mint(tx.origin, 1000000 * (10 ** uint256(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MaliciousHookScript is Script {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    // The two currencies (tokens) from the pool
    Currency token0;
    Currency token1;
    IPoolManager manager;
    PoolKey key;
    address hookAddr;

    MaliciousHook hook;
    address deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    // address deployer = msg.sender;
    // address router = 0x841B5A0b3DBc473c8A057E2391014aa4C4751351;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    

    function run() public {
        vm.startBroadcast();
        address token0_addr = address(0x0197481B0F5237eF312a78528e79667D8b33Dcff);
        address token1_addr = address(0xA56569Bd93dc4b9afCc871e251017dB0543920d4);

        if (token0_addr > token1_addr) {
            address temp = token0_addr;
            token0_addr = token1_addr;
            token1_addr = temp;
        }

        token0 = Currency.wrap(token0_addr);
        token1 = Currency.wrap(token1_addr);

        // Deploy our hook
        uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG);

        manager = IPoolManager(0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);
        // modifyLiquidityRouter = new PoolModifyLiquidityTest(IPoolManager(manager));

        bytes memory implBytecode = type(MaliciousHook).creationCode;
        (address addr, uint256 hookSalt) =
            HookMiner.find(address(deployer), flags, implBytecode, abi.encode(manager));
        addr = address(new MaliciousHook{salt: bytes32(hookSalt)}(manager));
        hookAddr = payable(addr);

        key = PoolKey(token0, token1, 0, 60, IHooks(hookAddr));

        PoolId poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, "");

        console.logAddress(hookAddr);
        console.logAddress(token0_addr);
        console.logAddress(token1_addr);
        // console.logAddress(address(modifyLiquidityRouter));

        hook = MaliciousHook(hookAddr);

        // Token0(token0_addr).mint(address(manager), 100 ether);
        // Token1(token1_addr).mint(address(manager), 100 ether);
        
        // tmodifyLiquidity(hookAddr);


    }

    function tmodifyLiquidity(address _hookAddr) public {
        Token0 a = Token0(Currency.unwrap(token0));
        Token1 b = Token1(Currency.unwrap(token1));
        // a.mint(address(msg.sender), 100 ether);
        // b.mint(address(msg.sender), 100 ether);
        Currency aa = Currency.wrap(address(a));
        Currency bb = Currency.wrap(address(b));
        key = PoolKey(aa, bb, 100, 2, IHooks(_hookAddr));

        a.approve(address(modifyLiquidityRouter), 1 ether);
        b.approve(address(modifyLiquidityRouter), 1 ether);

        IPoolManager.ModifyLiquidityParams memory aaaa =
        IPoolManager.ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0});
        modifyLiquidityRouter.modifyLiquidity(
            key,
            aaaa,
            new bytes(0)
        );
    }

}
