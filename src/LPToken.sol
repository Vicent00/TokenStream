// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public immutable dex;

    constructor() ERC20("DEX LP Token", "DLP") {
        dex = msg.sender;
    }

    modifier onlyDEX() {
        require(msg.sender == dex, "LPToken: ONLY_DEX");
        _;
    }

    function mint(address to, uint256 amount) external onlyDEX {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyDEX {
        _burn(from, amount);
    }
} 