# YiDengToken 合约文档

## 合约概述

YiDengToken (YD) 是一个基于 ERC20 标准的代币合约，支持用户使用 ETH 兑换 YD 代币。合约继承了 OpenZeppelin 的 ERC20、ERC20Burnable 和 Ownable 模块，提供代币标准功能、销毁机制和权限管理。

---

## 代币信息

- **代币名称**: YiDengToken
- **代币符号**: YD
- **标准**: ERC20
- **Solidity 版本**: ^0.8.28
- **许可证**: MIT

---

## 核心功能

### 1. 代币铸造
```solidity
function mint(address to, uint256 amount) public onlyOwner
```

- **功能**: 向指定地址铸造指定数量的 YD 代币
- **权限**: 仅合约所有者
- **参数**:
  - `to`: 接收代币的地址
  - `amount`: 铸造的代币数量

### 2. 代币销毁

继承自 `ERC20Burnable`，提供以下功能：
- 持有者可以销毁自己的代币
- 持有者可以销毁授权给自己的代币
- 销毁后总供应量相应减少

### 3. 兑换比例管理
```solidity
function setExchangeRate(uint256 _newRate) external onlyOwner
```

- **功能**: 设置 ETH 到 YD 的兑换比例
- **权限**: 仅合约所有者
- **参数**:
  - `_newRate`: 新的兑换比例（1 ETH 可兑换多少 YD）
- **限制**: 兑换比例必须大于 0
- **事件**: 触发 `ExchangeRateUpdated` 事件

### 4. ETH 兑换 YD 代币
```solidity
function exchangeETHForTokens() public payable
```

- **功能**: 用户发送 ETH 到合约，按设定比例获得新铸造的 YD 代币
- **权限**: 公开可调用
- **支付**: 需要发送 ETH（payable）
- **兑换机制**: 直接铸造新代币给用户，无需合约预存代币
- **计算公式**: `YD 数量 = ETH 数量 × exchangeRate`
- **前置条件**:
  - 发送的 ETH 数量必须大于 0
  - 兑换比例必须已设置（大于 0）
  - 计算得到的 YD 数量必须大于 0
- **事件**: 触发 `TokenExchanged` 事件

### 5. 自动兑换
```solidity
receive() external payable
```

- **功能**: 用户直接向合约地址转账 ETH 时自动触发兑换
- **调用**: 自动调用 `exchangeETHForTokens()` 函数

---

## 状态变量

| 变量名 | 类型 | 可见性 | 说明 |
|--------|------|--------|------|
| `exchangeRate` | uint256 | public | ETH 到 YD 的兑换比例 |

---

## 事件

### ExchangeRateUpdated
```solidity
event ExchangeRateUpdated(uint256 newRate)
```

- **触发时机**: 所有者更新兑换比例时
- **参数**: 新的兑换比例

### TokenExchanged
```solidity
event TokenExchanged(address indexed user, uint256 ethAmount, uint256 ydAmount)
```

- **触发时机**: 用户成功兑换代币时
- **参数**:
  - `user`: 兑换用户地址（索引）
  - `ethAmount`: 支付的 ETH 数量
  - `ydAmount`: 获得的 YD 数量

---

## 权限控制

合约使用 OpenZeppelin 的 `Ownable` 模式进行权限管理：

| 功能 | 权限要求 |
|------|----------|
| 铸造代币 (`mint`) | 仅所有者 |
| 设置兑换比例 (`setExchangeRate`) | 仅所有者 |
| 兑换代币 (`exchangeETHForTokens`) | 任何人 |
| 销毁代币 | 代币持有者 |
| 转移所有权 | 当前所有者 |

---

## 使用流程

### 初始化流程

1. 部署合约，指定初始所有者地址
2. 所有者调用 `setExchangeRate()` 设置兑换比例

### 用户兑换流程

**方式一：调用函数兑换**
```solidity
// 用户发送 1 ETH 兑换 YD 代币
contract.exchangeETHForTokens{value: 1 ether}();
```

**方式二：直接转账**
```solidity
// 用户直接向合约地址转账 1 ETH
// 自动触发兑换功能
address(contract).transfer(1 ether);
```

### 兑换示例

假设兑换比例设置为 1000：
- 用户发送 1 ETH → 获得 1000 YD
- 用户发送 0.5 ETH → 获得 500 YD
- 用户发送 2 ETH → 获得 2000 YD

---

## 安全特性

1. **权限隔离**: 关键功能（铸造、设置比例）仅限所有者操作
2. **输入验证**: 所有关键函数都包含输入验证
3. **事件记录**: 重要操作都会触发事件，便于追踪和审计
4. **标准继承**: 使用 OpenZeppelin 经过审计的合约库

---

## 注意事项

⚠️ **重要提示**:
1. 合约会将接收到的 ETH 永久锁定在合约中，没有提供提取 ETH 的功能
2. 兑换时直接铸造新代币，理论上可以无限增发
3. 所有者权限较大，需妥善保管私钥
4. 建议在主网部署前进行完整的安全审计

---

## 合约地址

- **网络**: [待部署]
- **合约地址**: [待部署]
- **所有者地址**: [待部署]

---

## 版本历史

- **v1.0**: 初始版本，支持 ETH 兑换 YD 功能