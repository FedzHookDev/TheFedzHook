import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {NFTAccessScheduler} from "./NFTAccessScheduler.sol";
import {NFTWhitelist} from "./NFTWhitelist.sol";
import {TurnBasedSystem} from "./TurnBasedSystem.sol";
import {NFTAccessScheduler} from "./NFTAccessScheduler.sol";


contract FedzHook is BaseHook, NFTWhitelist  {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint256 depegThreshold;
    int24 depegTick;
    address USDT;
    address FUSD;
    uint24 baseFee;
    uint24 crisisFee;
    bool isInCrisis;

    TurnBasedSystem public immutable turnSystem;


    

    address public manager;

    struct UserLiquidity{
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
    }

    event DepegThresholdUpdated(uint256 newThreshold);
    event CrisisStateChanged(bool isInCrisis);
    event LiquidityAdded(address user, uint128 amount);
    event LiquidityRemoved(address user, uint128 amount);
    event BeforeSwapExecuted(address user, bool zeroForOne, int256 amountIn);

    event AfterSwapExecuted(address user, bool zeroForOne, int256 amountIn);
    event RewardClaimed(address user, uint256 amount);
    event PriceIs(uint256 price); //Test only
   
    constructor(
        address _owner,
        IPoolManager _poolManager,
        address _nftContract,
        address _USDT,
        address _FUSD,
        uint256 _depegThreshold, 
        address _turnSystem

        
    ) BaseHook(_poolManager) NFTWhitelist(  _nftContract, _owner) {
        manager = _owner;
        USDT = _USDT;
        FUSD = _FUSD;
        depegThreshold = _depegThreshold;
        turnSystem = TurnBasedSystem(_turnSystem);

        baseFee = 3000; // 0.01%
        crisisFee = 6000; // 0.1%
        isInCrisis = false;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory){
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }


    /*
    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: true,
            afterInitialize: true,
            beforeModifyPosition: true,
            afterModifyPosition: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true
        });
    }
    */

    modifier _checkPlayerTurn(address player) {
        require(turnSystem.isPlayerTurn(player), "Not player's turn");
        _;
    }

    function beforeAddLiquidity(
        address sender, // sender
        PoolKey calldata key, // key
        IPoolManager.ModifyLiquidityParams calldata params, // params
        bytes calldata // data
    )
        external
        _checkPlayerTurn(sender)
        onlyNFTOwner(sender)
        override

        
        returns (bytes4)
    {

        
        // Get the current sqrt(price) from the pool
        uint160 currentSqrtPrice = getCurrentPrice(key);

        // Compare the current sqrt(price) directly with the depegThreshold
        if (currentSqrtPrice < depegThreshold) {
            revert("Price is below depeg threshold");
        }
        


        return IHooks.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender, // sender
        PoolKey calldata key, // key
        IPoolManager.ModifyLiquidityParams calldata, // params
        bytes calldata // data

    )
        external
        _checkPlayerTurn(sender)
        onlyNFTOwner(sender)
        override
        returns (bytes4)
    {
        
        // Get the current sqrt(price) from the pool
        uint160 currentSqrtPrice = getCurrentPrice(key);

        // Compare the current sqrt(price) directly with the depegThreshold
        if (currentSqrtPrice < depegThreshold) {
            revert("Price is below depeg threshold");
        }
        

        return IHooks.beforeRemoveLiquidity.selector;
    }

    

    

    function beforeSwap(
        address sender, // sender
        PoolKey calldata key, // key
        IPoolManager.SwapParams calldata params, // params
        bytes calldata // data
    )
        external
        //_checkPlayerTurn(sender)
        onlyNFTOwner(sender)
        override

        returns (bytes4, BeforeSwapDelta, uint24)

    {
          // Check if it's the sender's turn
        //require(turnSystem.isPlayerTurn(sender), "Not your turn");

        
        // If the current player hasn't played, skip their turn
        if (!turnSystem.hasPlayerPlayed(turnSystem.getCurrentPlayer())) {
            turnSystem.skipTurn(sender);
        } else {
            // If the current player has played, start the next turn
            turnSystem.startNextTurn(sender);
        }
    
        /* Should not be needed as price checks happens after swap
        // Get the current sqrt(price) from the pool
        uint160 currentSqrtPrice = getCurrentPrice(key);
        emit PriceIs(uint256(currentSqrtPrice));

        // Compare the current sqrt(price) directly with the depegThreshold
        if (currentSqrtPrice < depegThreshold) {
            revert("Price is below depeg threshold");
        }
        */
        
        uint24 fee = isInCrisis ? crisisFee : baseFee;
        emit BeforeSwapExecuted(sender, params.zeroForOne, params.amountSpecified);
        
        

        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), fee);
    }

    function afterSwap(
        address sender, // sender
        PoolKey calldata key, // key
        IPoolManager.SwapParams calldata params, // params
        BalanceDelta delta, // delta
        bytes calldata // data
    )
        external
        override
        returns (bytes4, int128)
    {
        // Get the current sqrt(price) from the pool
        uint160 currentSqrtPrice = getCurrentPrice(key);
        emit PriceIs(uint256(currentSqrtPrice));

        // Compare the current sqrt(price) directly with the depegThreshold
        if (currentSqrtPrice < depegThreshold) {
            revert("Price is below depeg threshold");
        }
        emit AfterSwapExecuted(sender, params.zeroForOne, params.amountSpecified);
        return (IHooks.afterSwap.selector, 0);
    }

    /*

    function getHookSwapFee(PoolKey calldata) external pure returns (uint24) {
        return 3000;
    }

    function getHookWithdrawFee(PoolKey calldata) external pure returns (uint24) {
        return 6000;
    }

    function getHookFees(PoolKey calldata key) external view returns (uint24){
        return 3000;
    }

    function getFee(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data) external returns (uint24){
        return 10000;
    }

    function setDepegThreshold(uint256 newThreshold) external onlyOwner {
        depegThreshold = newThreshold;
        emit DepegThresholdUpdated(newThreshold);
    }

    function setFees(uint24 newBaseFee, uint24 newCrisisFee) external onlyOwner {
        baseFee = newBaseFee;
        crisisFee = newCrisisFee;
    }

    function setCrisisState(bool _isInCrisis) external onlyOwner {
        isInCrisis = _isInCrisis;
        emit CrisisStateChanged(_isInCrisis);
    }

    /*
    function _storeUserPosition(address user, IPoolManager.ModifyLiquidityParams calldata params) internal{
        //get user liquidity
        int24 tickLower = params.tickLower;
        int24 tickUpper = params.tickUpper;

        PoolKey memory key = _getPoolKey();
        (uint160 sqrtPriceX96, int24 currentTick, ,  ) = poolManager.getSlot0(key.toId());
        uint128 userLiquidity = poolManager.getLiquidity(key.toId(),user,  tickLower, tickUpper);
        
        userPosition[user] = UserLiquidity(
            userLiquidity,
            tickLower,
            tickUpper
        );
        


    }
    */
    
    


    //TODO check if this is needed
    mapping(address => uint256) private lastInteractionTime;

    function checkFlashloanPrevention(address user) internal {
        require(block.timestamp - lastInteractionTime[user] > 1, "Potential flashloan detected");
        lastInteractionTime[user] = block.timestamp;
    }
    

    function getCurrentPrice(PoolKey memory poolKey) public view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
    }

    function calculatePrice2(uint160 sqrtPriceX96, uint8 token0Decimals, uint8 token1Decimals) public  returns (uint256) {
        uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * (10**token1Decimals) / (2**192) / (10**token0Decimals);
        emit PriceIs(price);
        return price;
    }

     function calculatePrice(uint160 sqrtPriceX96) public  returns (uint256) {
        uint256 price = uint256(sqrtPriceX96) **2  / (2**192);
        emit PriceIs(price);
        return price;
    }

    function getCurrentTick(PoolKey memory poolKey) public view returns (int24 tick) {
        (, tick,,) = poolManager.getSlot0(poolKey.toId());
        return tick;
    }

    function tickToPrice(int24 tick, uint8 token0Decimals, uint8 token1Decimals) public pure returns (uint256) {
    uint256 price;
        if (tick >= 0) {
            price = uint256(1e18);
            for (int24 i = 0; i < tick; i++) {
                price = (price * 10001) / 10000;
            }
        } else {
            price = uint256(1e18);
            for (int24 i = tick; i < 0; i++) {
                price = (price * 10000) / 10001;
            }
        }

        // Adjust for decimal places
        if (tick >= 0) {
            return (price * 10 ** (token1Decimals + 18 - token0Decimals)) / 1e18;
        } else {
            return (10 ** (token0Decimals + 18 + token1Decimals)) / price;
        }
    }


    function getDecimals(Currency currency) public view returns (uint8) {
        if (currency.isNative()) {
            return 18; // ETH (or native currency) always has 18 decimals
        } else {
            address tokenAddress = Currency.unwrap(currency);
            return IERC20Metadata(tokenAddress).decimals();
        }
    }


    //Helper function to return PoolKey
    function _getPoolKey() private view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(FUSD)),
            currency1: Currency.wrap(address(USDT)),
            fee:  100, // 0xE00000 = 111 //todo change fee accordingly
            tickSpacing: 60,
            hooks: IHooks(address(this))
        });
    }
}