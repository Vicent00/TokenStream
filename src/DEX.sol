// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract DEX is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable factory;
    IUniswapV2Router02 public immutable router;
    
    // Constants for slippage protection
    uint256 public constant MAX_SLIPPAGE = 500; // 5% max slippage
    uint256 public constant MIN_LIQUIDITY = 1000; // Minimum liquidity in wei
    
    // Mapping to track valid tokens
    mapping(address => bool) public validTokens;
    
    // Events
    event AddLiquidity(address indexed sender, address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 liquidity);
    event SwapTokens(address indexed sender, uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline, uint256 amountDaiseller, uint256 amountUsdtseller);
    event RemoveLiquidity(address indexed sender, address tokenA, address tokenB, uint256 liquidity, uint256 amountA, uint256 amountB);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    constructor(address _factory, address _router) Ownable(msg.sender) {
        require(_factory != address(0), "DEX: INVALID_FACTORY");
        require(_router != address(0), "DEX: INVALID_ROUTER");
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);
    }

    // Function to add valid tokens
    function addValidToken(address token) external onlyOwner {
        require(token != address(0), "DEX: INVALID_TOKEN");
        require(!validTokens[token], "DEX: TOKEN_ALREADY_ADDED");
        validTokens[token] = true;
        emit TokenAdded(token);
    }

    // Function to remove valid tokens
    function removeValidToken(address token) external onlyOwner {
        require(validTokens[token], "DEX: TOKEN_NOT_ADDED");
        validTokens[token] = false;
        emit TokenRemoved(token);
    }

    // Function to create a new pool
    function createPool(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != address(0) && tokenB != address(0), "DEX: ZERO_ADDRESS");
        require(tokenA != tokenB, "DEX: IDENTICAL_ADDRESSES");
        require(validTokens[tokenA] && validTokens[tokenB], "DEX: INVALID_TOKENS");
        require(factory.getPair(tokenA, tokenB) == address(0), "DEX: PAIR_EXISTS");

        pair = factory.createPair(tokenA, tokenB);
    }

    // Function to add liquidity with slippage protection
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(validTokens[tokenA] && validTokens[tokenB], "DEX: INVALID_TOKENS");
        require(amountADesired > 0 && amountBDesired > 0, "DEX: INVALID_AMOUNTS");
        require(amountAMin > 0 && amountBMin > 0, "DEX: INVALID_MIN_AMOUNTS");
        require(deadline >= block.timestamp, "DEX: EXPIRED");
        
        // Calculate max slippage
        uint256 maxSlippageA = (amountADesired * MAX_SLIPPAGE) / 10000;
        uint256 maxSlippageB = (amountBDesired * MAX_SLIPPAGE) / 10000;
        require(amountAMin >= amountADesired - maxSlippageA, "DEX: EXCESSIVE_SLIPPAGE_A");
        require(amountBMin >= amountBDesired - maxSlippageB, "DEX: EXCESSIVE_SLIPPAGE_B");

        // Transfer tokens to contract
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBDesired);

        // Approve router
        IERC20(tokenA).approve(address(router), amountADesired);
        IERC20(tokenB).approve(address(router), amountBDesired);

        // Add liquidity
        (amountA, amountB, liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadline
        );

        // Return excess tokens
        if (amountA < amountADesired) {
            IERC20(tokenA).safeTransfer(msg.sender, amountADesired - amountA);
        }
        if (amountB < amountBDesired) {
            IERC20(tokenB).safeTransfer(msg.sender, amountBDesired - amountB);
        }

        emit AddLiquidity(msg.sender, tokenA, tokenB, amountADesired, amountBDesired, liquidity);
    }

    // Function to remove liquidity with slippage protection
    function removeLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 liquidity_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        address to_,
        uint256 deadline_
    ) external returns (uint256 amountA, uint256 amountB) {
        // Obtener la dirección del par
        address pair = factory.getPair(tokenA_, tokenB_);
        require(pair != address(0), "DEX: PAIR_DOES_NOT_EXIST");

        // Verify that the user has enough LP tokens
        require(IERC20(pair).balanceOf(msg.sender) >= liquidity_, "DEX: INSUFFICIENT_LP_BALANCE");

        // Transfer LP tokens to contract
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity_);

        // Approve router
        IERC20(pair).approve(address(router), liquidity_);

        // Remove liquidity
        (amountA, amountB) = router.removeLiquidity(
            tokenA_,
            tokenB_,
            liquidity_,
            amountAMin_,
            amountBMin_,
            to_,
            deadline_
        );

        emit RemoveLiquidity(msg.sender, tokenA_, tokenB_, liquidity_, amountA, amountB);
    }

    // Function to swap tokens with slippage protection
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(path.length >= 2, "DEX: INVALID_PATH");
        require(amountIn > 0, "DEX: INVALID_AMOUNT_IN");
        require(amountOutMin > 0, "DEX: INVALID_AMOUNT_OUT_MIN");
        require(deadline >= block.timestamp, "DEX: EXPIRED");
        
        // Verify all tokens in path are valid
        for (uint256 i = 0; i < path.length; i++) {
            require(validTokens[path[i]], "DEX: INVALID_TOKEN_IN_PATH");
        }

        // Calculate max slippage
        uint256 maxSlippage = (amountIn * MAX_SLIPPAGE) / 10000;
        require(amountOutMin >= amountIn - maxSlippage, "DEX: EXCESSIVE_SLIPPAGE");

        // Transfer tokens to contract
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve router
        IERC20(path[0]).approve(address(router), amountIn);

        // Perform swap
        amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );

        // Transfer output tokens to recipient
        IERC20(path[path.length - 1]).safeTransfer(to, amounts[amounts.length - 1]);

        // Notify the tokenA how much tokens have been sent
        uint256 amountAseller = IERC20(path[0]).balanceOf(msg.sender);

        // Notify the tokenB how much tokens have been sent
        uint256 amountBseller = IERC20(path[path.length - 1]).balanceOf(msg.sender);

        emit SwapTokens(msg.sender, amountIn, amountOutMin, path, to, deadline, amountAseller, amountBseller);
    }

    // Función para obtener la cantidad de salida
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "DEX: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "DEX: INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}