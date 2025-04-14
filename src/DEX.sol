// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";


contract DEX {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable factory;
    IUniswapV2Router02 public immutable router;

    constructor(address _factory, address _router) {
        require(_factory != address(0), "DEX: INVALID_FACTORY");
        require(_router != address(0), "DEX: INVALID_ROUTER");
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);

    }


    // EVENTOS 
    event AddLiquidity(address indexed sender, address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 liquidity);
    event SwapTokens(address indexed sender, uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline, uint256 amountDaiseller, uint256 amountUsdtseller);
    event RemoveLiquidity(
        address indexed sender,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountA,
        uint256 amountB
    );

    // Función para crear un nuevo pool
    function createPool(address tokenA, address tokenB) external returns (address pair) {
        pair = factory.createPair(tokenA, tokenB);
    }

    // Función para añadir liquidez
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // Obtener la dirección del par
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "DEX: PAIR_DOES_NOT_EXIST");

        // Transferir tokens al contrato
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBDesired);
        // Aprobar al router
        IERC20(tokenA).approve(address(router), amountADesired);
        IERC20(tokenB).approve(address(router), amountBDesired);

        // Añadir liquidez
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

        // El router ya se encarga de:
        // 1. Transferir los tokens al par
        // 2. Mint los LP tokens
        // 3. Enviar los LP tokens a la dirección 'to'

        emit AddLiquidity(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    // Función para remover liquidez
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

        // Verificar que el usuario tiene suficientes LP tokens
        require(
            IERC20(pair).balanceOf(msg.sender) >= liquidity_,
            "DEX: INSUFFICIENT_LP_BALANCE"
        );

        // Transferir LP tokens al contrato
        IERC20(pair).safeTransferFrom(msg.sender, address(this), liquidity_);

        // Aprobar al router
        IERC20(pair).approve(address(router), liquidity_);

        // Remover liquidez
        (amountA, amountB) = router.removeLiquidity(
            tokenA_,
            tokenB_,
            liquidity_,
            amountAMin_,
            amountBMin_,
            to_,
            deadline_
        );

        // El router ya se encarga de:
        // 1. Quemar los LP tokens
        // 2. Transferir los tokens subyacentes a la dirección 'to'

        emit RemoveLiquidity(msg.sender, tokenA_, tokenB_, liquidity_, amountAMin_, amountBMin_);
    }

    // Función para hacer swap
    function swapExactTokensForTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] calldata path_,
        address to_,
        uint256 deadline_
    ) external returns (uint256[] memory amounts) {
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).approve(address(router), amountIn_);

        // Hacer swap
        amounts = router.swapExactTokensForTokens(
            amountIn_,
            amountOutMin_,
            path_,
            to_,
            deadline_
        );

       IERC20(path_[path_.length - 1]).safeTransfer(to_, amounts[amounts.length - 1]);

        // Notify the tokenA how much tokens have been sent
        uint256 amountAseller_ = IERC20(path_[0]).balanceOf(msg.sender);

        // Notify the tokenB how much tokens have been sent
        uint256 amountBseller_ = IERC20(path_[path_.length - 1]).balanceOf(msg.sender);

        emit SwapTokens(msg.sender, amountIn_, amountOutMin_, path_, to_, deadline_, amountAseller_, amountBseller_);
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