// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract YiDengToken is ERC20, ERC20Burnable, Ownable {
    // 设置最大供应量
    uint256 public constant MAX_SUPPLY = 10000000 * 10 ** 18; // 10,000,000 YD

    // 兑换比例：1 ETH 可兑换多少 YD
    uint256 public exchangeRate;

    event ExchangeRateUpdated(uint256 newRate);
    event TokenExchanged(
        address indexed user,
        uint256 ethAmount,
        uint256 ydAmount
    );

    constructor(
        address initialOwner
    ) ERC20("YiDengToken", "YD") Ownable(initialOwner) {
        _mint(initialOwner, 1000000 * 10 ** decimals()); // 初始供应 1,000,000 YD
    }

    function mint(address to, uint256 amount) public onlyOwner {
        // 检查铸造后不会超过最大供应量
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    // 设置兑换比例（仅所有者）
    function setExchangeRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Exchange rate must be greater than 0");
        exchangeRate = _newRate;
        emit ExchangeRateUpdated(_newRate);
    }

    // 用 ETH 兑换 YD 币
    function exchangeETHForTokens() public payable {
        require(msg.value > 0, "ETH amount must be greater than 0");
        require(exchangeRate > 0, "Exchange rate not set");

        uint256 ydAmount = msg.value * exchangeRate;
        require(ydAmount > 0, "YD amount must be greater than 0");

        _mint(msg.sender, ydAmount);

        emit TokenExchanged(msg.sender, msg.value, ydAmount);
    }

    // 直接转账 ETH 时自动兑换
    receive() external payable {
        exchangeETHForTokens();
    }
}
