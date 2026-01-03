// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TSwapPool} from "src/TSwapPool.sol";

/**
 * @title Handler
 * @dev Base handler contract for invariant testing
 *
 * This contract defines a minimal set of actions that can be fuzzed:
 * - Swaps (WETH <-> PoolToken)
 * - Adding liquidity
 * - Removing liquidity
 *
 * It is intentionally simple and safe.
 * You can later extend it with:
 * - Multiple actors
 * - Ghost variables
 * - More aggressive bounds
 * - Selector filtering
 */
contract Handler is Test {
    TSwapPool public pool;
    ERC20Mock public poolToken;
    ERC20Mock public weth;

    constructor(
        TSwapPool _pool,
        ERC20Mock _poolToken,
        ERC20Mock _weth
    ) {
        pool = _pool;
        poolToken = _poolToken;
        weth = _weth;

        // Give the handler enough tokens to interact with the pool
        poolToken.mint(address(this), 1_000_000e18);
        weth.mint(address(this), 1_000_000e18);

        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        // Create a small LP position so withdraw() can also be fuzzed
        uint256 wethToDeposit = 10e18;
        uint256 poolTokensNeeded =
            pool.getPoolTokensToDepositBasedOnWeth(wethToDeposit);

        pool.deposit(
            wethToDeposit,
            0, // minimum LP tokens (kept simple)
            poolTokensNeeded,
            uint64(block.timestamp)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap WETH for PoolToken
    function swapWethForPoolToken(uint256 amountIn) external {
        uint256 balance = weth.balanceOf(address(this));
        if (balance == 0) return;

        amountIn = bound(amountIn, 1, balance);

        pool.swapExactInput(
            weth,
            amountIn,
            poolToken,
            0, // no slippage protection for base invariant
            uint64(block.timestamp)
        );
    }

    /// @notice Swap PoolToken for WETH
    function swapPoolTokenForWeth(uint256 amountIn) external {
        uint256 balance = poolToken.balanceOf(address(this));
        if (balance == 0) return;

        amountIn = bound(amountIn, 1, balance);

        pool.swapExactInput(
            poolToken,
            amountIn,
            weth,
            0,
            uint64(block.timestamp)
        );
    }

    /// @notice Add liquidity to the pool
    function depositLiquidity(uint256 wethAmount) external {
        uint256 minWeth = pool.getMinimumWethDepositAmount();
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance < minWeth) return;

        wethAmount = bound(wethAmount, minWeth, wethBalance);

        uint256 requiredPoolTokens =
            pool.getPoolTokensToDepositBasedOnWeth(wethAmount);

        if (poolToken.balanceOf(address(this)) < requiredPoolTokens) return;

        pool.deposit(
            wethAmount,
            0, // minimum LP tokens
            requiredPoolTokens,
            uint64(block.timestamp)
        );
    }

    /// @notice Remove liquidity from the pool
    function withdrawLiquidity(uint256 lpAmount) external {
        uint256 lpBalance = pool.balanceOf(address(this));

        // Keep at least 1 wei of LP to avoid draining the pool completely
        if (lpBalance <= 1) return;

        lpAmount = bound(lpAmount, 1, lpBalance - 1);

        uint256 totalLp = pool.totalLiquidityTokenSupply();
        if (totalLp == 0) return;

        uint256 wethReserves = weth.balanceOf(address(pool));
        uint256 poolTokenReserves = poolToken.balanceOf(address(pool));

        uint256 wethOut = (lpAmount * wethReserves) / totalLp;
        uint256 poolTokenOut = (lpAmount * poolTokenReserves) / totalLp;

        // withdraw() requires non-zero minimum outputs
        if (wethOut == 0 || poolTokenOut == 0) return;

        pool.withdraw(
            lpAmount,
            1, // minimum WETH out (non-zero)
            1, // minimum PoolToken out (non-zero)
            uint64(block.timestamp)
        );
    }
}
