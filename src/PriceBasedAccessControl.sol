// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";


contract PriceBasedAccessControl is Ownable {
    PoolId public poolId;
    uint256 public tolerance; // Tolerance in basis points (1 basis point = 0.01%)

    event ToleranceUpdated(uint256 newTolerance);
    event PoolUpdated(PoolId indexed newPool);

    constructor(PoolId _poolId, uint256 _tolerance, address initalOwner) Ownable(initalOwner) {
        poolId = _poolId;
        tolerance = _tolerance;
    }

    function updateTolerance(uint256 _tolerance) external onlyOwner {
        tolerance = _tolerance;
        emit ToleranceUpdated(_tolerance);
    }

    function updatePool(PoolId _poolId) external onlyOwner {
        poolId = _poolId;
        emit PoolUpdated(_poolId);
    }
    /* What is this fonction supposed to do? Uniswap v4 pools are not supposed to be balanced since all Lps have different ranges

    function isBalanced() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pool.getReserves();
        uint256 totalSupply = reserve0 + reserve1;
        uint256 delta = (reserve0 > reserve1) ? reserve0 - reserve1 : reserve1 - reserve0;
        uint256 deltaPercentage = (delta * 10000) / totalSupply; // Basis points

        return deltaPercentage <= tolerance;
    }
    */

    function canPerformAction() external view returns (bool) {
        //return isBalanced();
    }
}
