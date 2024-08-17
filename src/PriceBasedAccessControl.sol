// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v4-core/contracts/interfaces/IUniswapV4Pool.sol";

contract PriceBasedAccessControl is Ownable {
    IUniswapV4Pool public pool;
    uint256 public tolerance; // Tolerance in basis points (1 basis point = 0.01%)

    event ToleranceUpdated(uint256 newTolerance);
    event PoolUpdated(address indexed newPool);

    constructor(address _pool, uint256 _tolerance) {
        pool = IUniswapV4Pool(_pool);
        tolerance = _tolerance;
    }

    function updateTolerance(uint256 _tolerance) external onlyOwner {
        tolerance = _tolerance;
        emit ToleranceUpdated(_tolerance);
    }

    function updatePool(address _pool) external onlyOwner {
        pool = IUniswapV4Pool(_pool);
        emit PoolUpdated(_pool);
    }

    function isBalanced() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        uint256 totalSupply = reserve0 + reserve1;
        uint256 delta = (reserve0 > reserve1) ? reserve0 - reserve1 : reserve1 - reserve0;
        uint256 deltaPercentage = (delta * 10000) / totalSupply; // Basis points

        return deltaPercentage <= tolerance;
    }

    function canPerformAction() external view returns (bool) {
        return isBalanced();
    }
}
