// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract DEX is Ownable {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public immutable factory;
    IUniswapV2Router02 public immutable router;

    constructor(address _factory, address _router) Ownable(msg.sender) {
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
    require(tokenA != address(0) && tokenB != address(0), "DEX: ZERO_ADDRESS");
    require(tokenA != tokenB, "DEX: IDENTICAL_ADDRESSES");
    require(factory.getPair(tokenA, tokenB) == address(0), "DEX: PAIR_EXISTS");

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

// Interfaz de usuario


    // Estructura para información del par
    struct PairInfo {
        address pairAddress;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
    }

    // Obtener información básica de un par
    function getPairInfo(address tokenA, address tokenB) external view returns (PairInfo memory) {
        address pairAddress = factory.getPair(tokenA, tokenB);
        require(pairAddress != address(0), "DEX: PAIR_DOES_NOT_EXIST");
        
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        
        return PairInfo({
            pairAddress: pairAddress,
            token0: pair.token0(),
            token1: pair.token1(),
            reserve0: reserve0,
            reserve1: reserve1,
            totalSupply: pair.totalSupply()
        });
    }

    // Obtener la liquidez del usuario
    function getUserLiquidity(address user, address tokenA, address tokenB) external view returns (uint256) {
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) return 0;
        return IERC20(pair).balanceOf(user);
    }

    // Calcular cantidad de salida esperada
    function getExpectedOutputAmount(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "DEX: INVALID_PATH");
        return router.getAmountsOut(amountIn, path);
    }

    // Verificar si existe un par
    function pairExists(address tokenA, address tokenB) external view returns (bool) {
        return factory.getPair(tokenA, tokenB) != address(0);
    }

    // Obtener precio actual
    function getCurrentPrice(address tokenA, address tokenB) external view returns (uint256) {
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "DEX: PAIR_DOES_NOT_EXIST");
        
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        
        if (tokenA == token0) {
            return (reserve1 * 1e18) / reserve0;
        } else {
            return (reserve0 * 1e18) / reserve1;
        }
    }

    // Obtener todos los pares activos de un token
    function getTokenPairs(address token) external view returns (address[] memory pairs) {
        uint256 totalPairs = factory.allPairsLength();
        address[] memory tempPairs = new address[](totalPairs);
        uint256 count = 0;
        
        for (uint256 i = 0; i < totalPairs; i++) {
            address pair = factory.allPairs(i);
            IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
            
            if (pairContract.token0() == token || pairContract.token1() == token) {
                tempPairs[count] = pair;
                count++;
            }
        }
        
        pairs = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            pairs[i] = tempPairs[i];
        }
    }

    // Obtener información de liquidez del usuario
    function getUserLiquidityInfo(
        address user,
        address tokenA,
        address tokenB
    ) external view returns (uint256 lpBalance, uint256 token0Amount, uint256 token1Amount) {
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) return (0, 0, 0);
        
        lpBalance = IERC20(pair).balanceOf(user);
        if (lpBalance == 0) return (0, 0, 0);
        
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        uint256 totalSupply = pairContract.totalSupply();
        (uint256 reserve0, uint256 reserve1,) = pairContract.getReserves();
        
        token0Amount = (lpBalance * reserve0) / totalSupply;
        token1Amount = (lpBalance * reserve1) / totalSupply;
    }

    // Obtener historial de swaps recientes
    function getRecentSwaps(uint256 limit) external view returns (address[] memory tokens, uint256[] memory amounts) {
        // Esta función sería implementada con un mapping de historial de swaps
        // Por ahora retornamos arrays vacíos como placeholder
        tokens = new address[](0);
        amounts = new uint256[](0);
    }

    // Estructura para información de token
    struct TokenInfo {
        address tokenAddress;
        string symbol;
        uint256 decimals;
        uint256 balance;
        uint256 allowance;
    }

    // Obtener información de un token
    function getTokenInfo(address token, address user) external view returns (TokenInfo memory) {
        IERC20 tokenContract = IERC20(token);
        return TokenInfo({
            tokenAddress: token,
            symbol: "", // Se necesitaría una interfaz ERC20 extendida para obtener el símbolo
            decimals: 18, // Se necesitaría una interfaz ERC20 extendida para obtener los decimales
            balance: tokenContract.balanceOf(user),
            allowance: tokenContract.allowance(user, address(this))
        });
    }

    // Calcular slippage
    function calculateSlippage(
        uint256 amountIn,
        uint256 amountOut,
        uint256 expectedAmountOut
    ) external pure returns (uint256 slippage) {
        if (expectedAmountOut == 0) return 0;
        slippage = ((expectedAmountOut - amountOut) * 10000) / expectedAmountOut;
    }

    // Obtener información de liquidez total
    function getTotalLiquidityInfo(
        address tokenA,
        address tokenB
    ) external view returns (uint256 totalLiquidity, uint256 token0Liquidity, uint256 token1Liquidity) {
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) return (0, 0, 0);
        
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        (uint256 reserve0, uint256 reserve1,) = pairContract.getReserves();
        totalLiquidity = pairContract.totalSupply();
        token0Liquidity = reserve0;
        token1Liquidity = reserve1;
    }

    // Calcular precio de impacto
    function calculatePriceImpact(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256 priceImpact) {
        require(path.length >= 2, "DEX: INVALID_PATH");
        
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        uint256 expectedOutput = amounts[amounts.length - 1];
        
        address pair = factory.getPair(path[0], path[path.length - 1]);
        (uint256 reserveIn, uint256 reserveOut,) = IUniswapV2Pair(pair).getReserves();
        
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        uint256 actualOutput = numerator / denominator;
        
        if (expectedOutput > actualOutput) {
            priceImpact = ((expectedOutput - actualOutput) * 10000) / expectedOutput;
        } else {
            priceImpact = 0;
        }
    }

    // Verificar aprobación de tokens
    function checkTokenApproval(
        address token,
        address user,
        uint256 amount
    ) external view returns (bool) {
        return IERC20(token).allowance(user, address(this)) >= amount;
    }

    // Obtener información de pool
    function getPoolInfo(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 price0,
        uint256 price1,
        uint256 volume24h
    ) {
        address pair = factory.getPair(tokenA, tokenB);
        if (pair == address(0)) return (0, 0, 0, 0, 0, 0);
        
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        (reserve0, reserve1,) = pairContract.getReserves();
        totalSupply = pairContract.totalSupply();
        
        price0 = reserve1 > 0 ? (reserve1 * 1e18) / reserve0 : 0;
        price1 = reserve0 > 0 ? (reserve0 * 1e18) / reserve1 : 0;
        
        // El volumen de 24h necesitaría ser implementado con un sistema de tracking
        volume24h = 0;
    }

    // Calcular cantidades mínimas para swap
    function calculateMinAmounts(
        uint256 amountIn,
        uint256 slippage
    ) external pure returns (uint256 minAmount) {
        minAmount = (amountIn * (10000 - slippage)) / 10000;
    }

    // Verificar si un token está en la lista blanca
    function isTokenWhitelisted(address token) external view returns (bool) {
        // Esta función necesitaría un mapping de tokens permitidos
        return true; // Por ahora todos los tokens están permitidos
    }

    // Obtener información de fees
    function getFeeInfo() external pure returns (uint256 swapFee, uint256 protocolFee) {
        swapFee = 30; // 0.3%
        protocolFee = 5; // 0.05%
    }

    // Calcular fees para una transacción
    function calculateFees(
        uint256 amount,
        bool isSwap
    ) external pure returns (uint256 fee) {
        if (isSwap) {
            fee = (amount * 30) / 10000; // 0.3% para swaps
        } else {
            fee = (amount * 5) / 10000; // 0.05% para otras operaciones
        }
    }
}