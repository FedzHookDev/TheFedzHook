# The Fedz Project

Welcome to **The Fedz** – a revolutionary decentralized finance (DeFi) platform designed to redefine the stability and efficiency of stablecoins and synthetic derivatives in the blockchain ecosystem. Our mission is to create a robust financial mechanism that prevents bank runs, ensures liquidity, and enhances the stability of dollar derivatives with minimal capital requirements.

## The Fedz Project

The Fedz is pioneering a new category in DeFi, focusing on under-collateralized stablecoins and innovative financial instruments. By leveraging blockchain technology and advanced algorithmic models, The Fedz aims to address fundamental challenges in the current financial system, such as:

- **Preventing Bank Runs**: Implement mechanisms to mitigate the risk of panic withdrawals and ensure the security of users' assets.
- **Enhancing Liquidity**: Creating Private Liquidity Pools prioritizing stability and accessibility for NFT holders.
- **Developing a New Financial Model**: Utilizing blockchain technology to build a sustainable and scalable financial ecosystem that offers unique opportunities to both traditional and digital asset investors.

## Repository Structure

This repository hosts the core components of The Fedz platform. Below is an overview of the architecture and key directories:

### 1. Contracts
+--------------------+     +-----------------------+     +-------------------------+
|                    |     |                       |     |                         |
|  NFTWhitelist.sol   |     |  PriceBasedAccess-    |     |    NFTAccessScheduler   |
|                    |     |   Control.sol         |     |      .sol               |
|  - Manages NFT      |     |                       |     |                         |
|    whitelist        |     |  - Monitors pool      |     |  - Schedules access     |
|  - Adds/removes     |---->|    token ratio        |---->|    based on whitelist   |
|    addresses        |     |  - Ensures balance    |     |  - Determines current   |
|                    |     |    within tolerance    |     |    eligible address     |
+--------------------+     +-----------------------+     +-------------------------+
                                   |                           |
                                   |                           |
                                   |                           |
                                   |                           |
                                   v                           v
                            +------------------------------------------+
                            |                                          |
                            |            HookManager.sol               |
                            |                                          |
                            |  - Integrates NFTAccessScheduler and     |
                            |    PriceBasedAccessControl               |
                            |  - Manages access to the pool            |
                            |    according to the whitelist and        |
                            |    price balance                         |
                            |  - Ensures only one address can access   |
                            |    the pool at a time and the pool is    |
                            |    balanced before allowing interaction  |
                            |                                          |
                            +------------------------------------------+
                                              |
                                              v
                                       +----------------+
                                       |                |
                                       | Uniswap V4 Pool|
                                       |                |
                                       +----------------+

Flow and Relations:
NFTWhitelist.sol:

Role: Manages a list of whitelisted addresses based on NFT ownership.
Relation: Provides the list of addresses to NFTAccessScheduler.sol.
NFTAccessScheduler.sol:

Role: Manages the order and timing of access to the liquidity pool based on the whitelist.
Relation: Interacts with NFTWhitelist.sol to get the list of eligible addresses and schedules their turns to access the pool.
PriceBasedAccessControl.sol:

Role: Ensures the liquidity pool's token ratio remains balanced within a specified tolerance.
Relation: Monitors the token balances in the Uniswap V4 pool and provides access control based on price balance.
HookManager.sol:

Role: Integrates NFTAccessScheduler.sol and PriceBasedAccessControl.sol to manage access to the liquidity pool.
Relation: Combines the scheduling and price balance checks to ensure that only the current eligible address, according to the whitelist, can interact with the pool, and only if the pool's token ratio is balanced.
Uniswap V4 Pool:

Role: The actual liquidity pool where interactions (e.g., adding/removing liquidity).
Relation: HookManager.sol controls the access to this pool based on conditions from the NFTAccessScheduler.sol and PriceBasedAccessControl.sol.


## Getting Started

To start contributing or running The Fedz locally:

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/TheFedz/TheFedz.git
   cd TheFedz




# v4-template
### **A template for writing Uniswap v4 Hooks 🦄**

[`Use this Template`](https://github.com/uniswapfoundation/v4-template/generate)

1. The example hook [Counter.sol](src/Counter.sol) demonstrates the `beforeSwap()` and `afterSwap()` hooks
2. The test template [Counter.t.sol](test/Counter.t.sol) preconfigures the v4 pool manager, test tokens, and test liquidity.

<details>
<summary>Updating to v4-template:latest</summary>

This template is actively maintained -- you can update the v4 dependencies, scripts, and helpers: 
```bash
git remote add template https://github.com/uniswapfoundation/v4-template
git fetch template
git merge template/main <BRANCH> --allow-unrelated-histories
```

</details>

---

## Check Forge Installation
*Ensure that you have correctly installed Foundry (Forge) and that it's up to date. You can update Foundry by running:*

```
foundryup
```

## Set up

*requires [foundry](https://book.getfoundry.sh)*

```
forge install
forge test
```

### Local Development (Anvil)

Other than writing unit tests (recommended!), you can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/)

```bash
# start anvil, a local EVM chain
anvil

# in a new terminal
forge script script/Anvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

<details>
<summary><h3>Testnets</h3></summary>

NOTE: 11/21/2023, the Goerli deployment is out of sync with the latest v4. **It is recommend to use local testing instead**

~~For testing on Goerli Testnet the Uniswap Foundation team has deployed a slimmed down version of the V4 contract (due to current contract size limits) on the network.~~

~~The relevant addresses for testing on Goerli are the ones below~~

```bash
POOL_MANAGER = 0x0
POOL_MODIFY_POSITION_TEST = 0x0
SWAP_ROUTER = 0x0
```

Update the following command with your own private key:

```
forge script script/00_Counter.s.sol \
--rpc-url https://rpc.ankr.com/eth_goerli \
--private-key [your_private_key_on_goerli_here] \
--broadcast
```

### *Deploying your own Tokens For Testing*

Because V4 is still in testing mode, most networks don't have liquidity pools live on V4 testnets. We recommend launching your own test tokens and expirementing with them that. We've included in the templace a Mock UNI and Mock USDC contract for easier testing. You can deploy the contracts and when you do you'll have 1 million mock tokens to test with for each contract. See deployment commands below

```
forge create script/mocks/mUNI.sol:MockUNI \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key_on_goerli_here]
```

```
forge create script/mocks/mUSDC.sol:MockUSDC \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key_on_goerli_here]
```

</details>

---

<details>
<summary><h2>Troubleshooting</h2></summary>



### *Permission Denied*

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) 

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
    * `getHookCalls()` returns the correct flags
    * `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
    * In **forge test**: the *deploye*r for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
    * In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
        * If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

---

Additional resources:

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)

