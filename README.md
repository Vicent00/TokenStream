# TokenStream DEX


TokenStream DEX is a decentralized exchange (DEX) built on Solidity that enables secure and efficient ERC-20 token swaps. The project implements an Automated Market Maker (AMM) system similar to Uniswap V2, with additional security features and advanced functionalities.

## Overview

TokenStream DEX provides a robust platform for token trading with the following key features:
- Direct ERC-20 token swaps
- Liquidity provision system with LP tokens
- Advanced slippage protection
- Multi-layered security implementation
- Token validation system
- Complete liquidity management

## Screenshots

![DEX Interface](screenshots\structure.svg) <!-- Replace with actual screenshot -->
*TokenStream DEX Interface*


## Code Structure

### Core Contracts

#### DEX.sol
The main contract handling all exchange operations:
```solidity
contract DEX is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Core functionality
    function createPool(address tokenA, address tokenB) external returns (address pair)
    function addLiquidity(...) external nonReentrant
    function removeLiquidity(...) external
    function swapExactTokensForTokens(...) external nonReentrant
}
```

Key features:
- Pool creation and management
- Token swaps with slippage protection
- Liquidity provision and removal
- Token validation system
- Reentrancy protection

#### LPToken.sol
The liquidity provider token contract:
```solidity
contract LPToken is ERC20 {
    // Access control
    modifier onlyDEX() {
        require(msg.sender == dex, "LPToken: ONLY_DEX");
        _;
    }
    
    // Core functions
    function mint(address to, uint256 amount) external onlyDEX
    function burn(address from, uint256 amount) external onlyDEX
}
```

## Deployment

### Prerequisites
- Node.js (v14 or higher)
- Foundry
- Solidity 0.8.26
- OpenZeppelin Contracts

### Installation
1. Clone the repository:
```bash
git clone https://github.com/your-username/TokenStream.git
cd TokenStream
```

2. Install dependencies:
```bash
forge install
```

3. Compile contracts:
```bash
forge build
```



## Security Features

- Reentrancy protection using ReentrancyGuard
- Token whitelist system
- Slippage protection with MAX_SLIPPAGE constant
- SafeERC20 for token operations
- Ownable for administrative functions
- Amount validations
- Deadline checks

## Events

The contract emits several events for tracking:
- `AddLiquidity`: When liquidity is added to a pool
- `SwapTokens`: When a token swap is executed
- `RemoveLiquidity`: When liquidity is removed
- `TokenAdded`: When a new token is added
- `TokenRemoved`: When a token is removed

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions or support, please contact:
- Email: [your-email@example.com](mailto:your-email@example.com)
- Twitter: [@TokenStreamDEX](https://twitter.com/TokenStreamDEX)
- Discord: [TokenStream Community](https://discord.gg/tokenstream)

## Acknowledgments

- OpenZeppelin for base contracts
- Uniswap for AMM design inspiration
- Ethereum community for support
