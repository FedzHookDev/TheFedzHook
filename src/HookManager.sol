// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NFTAccessScheduler.sol";
import "./PriceBasedAccessControl.sol";
import "@uniswap/v4-core/src/types/PoolId.sol";

contract HookManager is Ownable {
    NFTAccessScheduler public accessScheduler;
    PriceBasedAccessControl public priceAccessControl;
    PoolId public poolId;


    event PoolUpdated(PoolId indexed newPool);
    event AccessSchedulerUpdated(address indexed newAccessScheduler);
    event PriceAccessControlUpdated(address indexed newPriceAccessControl);

    constructor(PoolId _poolId, address _accessScheduler, address _priceAccessControl, address initalOwner) Ownable(initalOwner) {
        poolId = _poolId;
        accessScheduler = NFTAccessScheduler(_accessScheduler);
        priceAccessControl = PriceBasedAccessControl(_priceAccessControl);
    }

    modifier onlyEligible() {
        require(accessScheduler.getCurrentTurn() == msg.sender, "Not your turn");
        require(priceAccessControl.canPerformAction(), "Pool not balanced");
        _;
    }

    function updatePool(PoolId _poolId) external onlyOwner {
        poolId = _poolId;
        emit PoolUpdated(_poolId);
    }

    function updateAccessScheduler(address _accessScheduler) external onlyOwner {
        accessScheduler = NFTAccessScheduler(_accessScheduler);
        emit AccessSchedulerUpdated(_accessScheduler);
    }

    function updatePriceAccessControl(address _priceAccessControl) external onlyOwner {
        priceAccessControl = PriceBasedAccessControl(_priceAccessControl);
        emit PriceAccessControlUpdated(_priceAccessControl);
    }

    function performAction() external onlyEligible {
        // Add your pool interaction code here
    }
}
