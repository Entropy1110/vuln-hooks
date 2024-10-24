// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

// Our contracts
import {HookCallerModifier} from "../src/HookCallerModifier.sol";
import {HookMiner} from "./HookMiner.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

import "forge-std/Script.sol";



contract Token0 is ERC20 {
    constructor () ERC20("Token0", "TK0") {
        _mint(tx.origin, 1000000 * (10 ** uint(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}

contract Token1 is ERC20 {
    constructor () ERC20 ("Token1", "TK1") {
        _mint(tx.origin, 1000000 * (10 ** uint(decimals())));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract HookCallerDeployerScript is Script {
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

    HookCallerModifier hook;
    address deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address router = 0x841B5A0b3DBc473c8A057E2391014aa4C4751351;
    PoolModifyLiquidityTest modifyLiquidityRouter = PoolModifyLiquidityTest(router);

    function run() public {
        vm.startBroadcast();
        // address token0_addr = address(new Token0());
        // address token1_addr = address(new Token1());
        address token0_addr = 0x6f0cD9aC99c852bDBA06F72db93078cbA80A32F5;
        address token1_addr = 0x8dB7EFd30A632eD236eAbde82286551f843D5487;
        if (token0_addr > token1_addr) {
            address temp = token0_addr;
            token0_addr = token1_addr;
            token1_addr = temp;
        }

        token0 = Currency.wrap(token0_addr);
        token1 = Currency.wrap(token1_addr);

        // Deploy our hook
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        

        manager = IPoolManager(	0x38EB8B22Df3Ae7fb21e92881151B365Df14ba967);

        bytes memory implBytecode = type(HookCallerModifier).creationCode;
        (address addr, uint hookSalt) = HookMiner.find(address(deployer), flags, implBytecode, abi.encode(manager));
        addr = address(new HookCallerModifier{salt: bytes32(hookSalt)}(manager));
        hookAddr = payable(addr);

        key = PoolKey(token0, token1, 0, 60, IHooks(hookAddr));

        PoolId poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, "");

        console.log("Hook address: ", hookAddr);
        console.log("Token0 address: ", token0_addr);
        console.log("Token1 address: ", token1_addr);



    }


    // function testModifyLiquidity() public {
    //     vm.startBroadcast();
    //     Token0 a = Token0(0x6f0cD9aC99c852bDBA06F72db93078cbA80A32F5);
    //     Token1 b = Token1(0x8dB7EFd30A632eD236eAbde82286551f843D5487);
    //     hookAddr = 0xce12A4E8980a70B0f4Bf16d89dD734dDb507Cac0;
    //     a.mint(address(this), 100 ether);
    //     b.mint(address(this), 100 ether);
    //     Currency aa = Currency.wrap(address(a));
    //     Currency bb = Currency.wrap(address(b));
    //     key = PoolKey(aa, bb, 0, 60, IHooks(hookAddr));

    //     a.approve(address(modifyLiquidityRouter), 100 ether);
    //     b.approve(address(modifyLiquidityRouter), 100 ether);


    //     modifyLiquidityRouter.modifyLiquidity(
    //         key,
    //         IPoolManager.ModifyLiquidityParams({
    //             tickLower: -60,
    //             tickUpper: 60,
    //             liquidityDelta: 10 ether,
    //             salt: bytes32(0)
    //         }),
    //         ""
    //     );
    // }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    
}
