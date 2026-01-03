// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {PoolFactory} from "src/PoolFactory.sol";
import {TSwapPool} from "src/TSwapPool.sol";
import {Handler} from "./Handler.t.sol";

/**
 * @title InvariantTest
 * @dev Base invariant test for TSwapPool + PoolFactory
 *
 * This file intentionally contains very simple invariants.
 * Its purpose is to provide a clean and extensible foundation.
 */
contract InvariantTest is StdInvariant, Test {
    ERC20Mock poolToken;
    ERC20Mock weth;

    PoolFactory factory;
    TSwapPool pool;
    Handler handler;

    uint256 constant STARTING_POOL_TOKENS = 1000e18;
    uint256 constant STARTING_WETH = 1000e18;

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();

        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        // Initial liquidity provided by the test contract
        poolToken.mint(address(this), STARTING_POOL_TOKENS);
        weth.mint(address(this), STARTING_WETH);

        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        pool.deposit(
            STARTING_WETH,
            0,
            STARTING_POOL_TOKENS,
            uint64(block.timestamp)
        );

        // Create handler and register it as the fuzz target
        handler = new Handler(pool, poolToken, weth);
        targetContract(address(handler));
    }

    /*//////////////////////////////////////////////////////////////
                                INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Factory mappings must remain consistent
    function invariant_factoryMappingsAreConsistent() public view {
        assertEq(factory.getPool(address(poolToken)), address(pool));
        assertEq(factory.getToken(address(pool)), address(poolToken));
        assertEq(factory.getWethToken(), address(weth));
    }

    /// @notice Pool token addresses must never change
    function invariant_poolTokenAddressesNeverChange() public view {
        assertEq(pool.getPoolToken(), address(poolToken));
        assertEq(pool.getWeth(), address(weth));
    }

    /// @notice Pool must never be completely drained
    function invariant_poolIsNeverEmpty() public view {
        assertGt(weth.balanceOf(address(pool)), 0);
        assertGt(poolToken.balanceOf(address(pool)), 0);
    }
}
