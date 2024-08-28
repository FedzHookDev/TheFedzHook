// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFUSD is ERC20 {
    constructor() ERC20("Mock FUSD", "mFUSD") {
        _mint(msg.sender, 10000000000000 * (10 ** uint256(decimals()))); // Mint 1 million mock FUSD to deployer
    }
}
