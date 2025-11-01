# Web3 大学 去中心化在线教育平台智能合约

Web3 大学 是一个基于区块链的去中心化在线教育平台，通过智能合约实现课程管理、代币经济、NFT 认证和社区治理功能。

## 项目概述

本项目包含四个核心智能合约：

- **YiDengToken (YD)**: ERC20 代币合约，支持 ETH 兑换功能
- **YiDengNFT (YDNFT)**: ERC721 NFT 合约，用于课程认证和成就展示
- **YiDengDAO**: DAO 治理合约，实现社区民主决策
- **CourseManage**: 课程管理合约，处理课程注册和购买

## 技术栈

- **Solidity**: ^0.8.28
- **Hardhat**: ^3.0.10
- **OpenZeppelin Contracts**: ^5.4.0
- **Ethers.js**: ^6.15.0
- **TypeScript**: ~5.8.3

## 目录结构

```
contract/
├── contracts/              # 智能合约源代码
│   ├── YiDengToken.sol    # YD 代币合约
│   ├── YiDengNFT.sol      # NFT 合约
│   ├── YiDengDAO.sol      # DAO 治理合约
│   └── CourseManage.sol   # 课程管理合约
├── ignition/modules/      # Hardhat Ignition 部署脚本
│   ├── YiDengToken.ts     # YD Token 部署模块
│   ├── YiDengNFT.ts       # NFT 部署模块
│   ├── YiDengDAO.ts       # DAO 部署模块
│   └── CourseManage.ts    # 课程管理部署模块
├── docs/                  # 详细文档
│   ├── YD币经济模型设计.md
│   ├── YiDengToken合约文档.md
│   ├── YiDengNFT合约文档.md
│   ├── YiDengDAO合约文档.md
│   └── CourseManage合约文档.md
└── hardhat.config.ts      # Hardhat 配置文件
```

## 合约介绍

### 1. YiDengToken (YD)

YD 是平台的治理和支付代币，基于 ERC20 标准。

**核心功能**:

- ETH 兑换 YD 代币
- 代币铸造（仅所有者）
- 代币销毁
- 动态调整兑换比例

**代币经济**:

- 总供应量: 1000 万枚
- 初始定价: 1 USD/YD
- 分配方案:
  - 社区空投: 10%
  - 早期投资者: 15%
  - 团队/顾问: 15%
  - 生态激励: 35%
  - Uniswap 流动性: 10%
  - 市场营销: 5%

详见: [YiDengToken 合约文档.md](docs/YiDengToken合约文档.md)

### 2. YiDengNFT (YDNFT)

NFT 合约用于课程完成认证和学习成就展示。

**核心功能**:

- 安全铸造 NFT
- NFT 转移和授权
- NFT 销毁
- URI 存储与查询

**应用场景**:

- 课程完成证书
- 学习成就徽章
- 社区身份标识
- 权益凭证

详见: [YiDengNFT 合约文档.md](docs/YiDengNFT合约文档.md)

### 3. YiDengDAO

去中心化自治组织合约，实现社区治理功能。

**核心功能**:

- 创建提案（需质押 YD）
- 一人一票投票机制
- 自动奖励分发
- 质押退还

**治理机制**:

- 投票期限: 7 天
- 通过条件: 赞成票 > 反对票
- 质押金额: 100 YD（可调整）
- 奖励规则: 胜诉方获得奖励，败诉方无惩罚

详见: [YiDengDAO 合约文档.md](docs/YiDengDAO合约文档.md)

### 4. CourseManage

课程管理合约，处理课程注册和购买。

**核心功能**:

- 课程注册（讲师）
- 课程购买（学生）
- 访问权限验证
- 自动收益分配

**分成机制**:

- 讲师: 90%
- 平台: 10%

**设计特点**:

- 合约不持有资金
- 直接转账模式
- 防重入攻击
- 课程 ID 由后端生成

详见: [CourseManage 合约文档.md](docs/CourseManage合约文档.md)

## 快速开始

### 环境要求

- Node.js >= 18.0.0
- npm 或 yarn

### 安装依赖

```bash
npm install
# 或
yarn install
```

### 编译合约

```bash
npx hardhat compile
```

### 运行测试

```bash
# 运行所有测试
npx hardhat test

# 运行 Solidity 测试
npx hardhat test solidity

# 运行 Mocha 测试
npx hardhat test mocha
```

## 部署指南

### 本地部署

#### 1. 启动本地节点

```bash
npx hardhat node
```

#### 2. 部署 YiDengToken

```bash
npx hardhat ignition deploy ignition/modules/YiDengToken.ts --network localhost
```

部署后会自动设置兑换比例为 1 ETH = 4000 YD。

#### 3. 部署 YiDengNFT

```bash
npx hardhat ignition deploy ignition/modules/YiDengNFT.ts --network localhost
```

#### 4. 部署 YiDengDAO

```bash
npx hardhat ignition deploy ignition/modules/YiDengDAO.ts --network localhost
```

DAO 合约会自动使用已部署的 YD Token 地址，默认质押金额为 100 YD。

#### 5. 部署 CourseManage

```bash
npx hardhat ignition deploy ignition/modules/CourseManage.ts --network localhost
```

CourseManage 会自动读取已部署的 YD Token 地址。

### Sepolia 测试网部署

#### 1. 配置私钥

```bash
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

#### 2. 配置 RPC URL

设置环境变量或使用 hardhat-keystore:

```bash
npx hardhat keystore set SEPOLIA_RPC_URL
```

#### 3. 部署合约

```bash
# 部署 YD Token
npx hardhat ignition deploy ignition/modules/YiDengToken.ts --network sepolia

# 部署 NFT
npx hardhat ignition deploy ignition/modules/YiDengNFT.ts --network sepolia

# 部署 DAO
npx hardhat ignition deploy ignition/modules/YiDengDAO.ts --network sepolia

# 部署课程管理
npx hardhat ignition deploy ignition/modules/CourseManage.ts --network sepolia
```

### 部署参数配置

#### YiDengToken 参数

- `initialOwner`: 合约所有者地址（默认: 第一个账户）
- `exchangeRate`: ETH 到 YD 的兑换比例（默认: 4000）

#### YiDengNFT 参数

- `initialOwner`: 合约所有者地址（默认: 第一个账户）

#### YiDengDAO 参数

- `ydTokenAddress`: YD Token 合约地址（自动获取）
- `stakeAmount`: 创建提案所需质押金额（默认: 100 YD）

#### CourseManage 参数

- `ydTokenAddress`: YD Token 合约地址（自动获取）
- `platformAddress`: 平台收款地址（需配置）

## 使用示例

### YiDengToken - ETH 兑换 YD

```javascript
// 用户发送 1 ETH 兑换 YD 代币
await ydToken.exchangeETHForTokens({ value: ethers.parseEther('1.0') })

// 或直接向合约地址转账
await signer.sendTransaction({
  to: ydTokenAddress,
  value: ethers.parseEther('1.0')
})
```

### YiDengNFT - 铸造 NFT

```javascript
// 所有者铸造 NFT
const recipient = '0x...'
const tokenURI = 'ipfs://QmXxx...'
const tokenId = await ydNFT.safeMint(recipient, tokenURI)
```

### YiDengDAO - 创建提案并投票

```javascript
// 1. 授权合约使用 YD 代币
await ydToken.approve(daoAddress, ethers.parseEther('100'))

// 2. 创建提案
await ydDAO.createProposal('proposal-001')

// 3. 投票
await ydDAO.vote('proposal-001', true) // 投赞成票

// 4. 7 天后执行提案（所有者操作）
await ydDAO.executeProposalAndDistributeRewards(
  'proposal-001',
  ethers.parseEther('100') // 每个胜诉方获得 100 YD
)
```

### CourseManage - 注册和购买课程

```javascript
// 讲师注册课程
const courseId = 'course-uuid-12345' // 后端生成
const price = ethers.parseEther('50') // 50 YD
await courseManage.registerCourse(courseId, price)

// 学生购买课程
// 1. 授权
await ydToken.approve(courseManageAddress, price)

// 2. 购买
await courseManage.purchaseCourse(courseId)

// 3. 验证访问权限
const hasAccess = await courseManage.hasAccess(studentAddress, courseId)
```

## 网络配置

本项目支持以下网络：

| 网络           | Chain ID | 说明               |
| -------------- | -------- | ------------------ |
| hardhatMainnet | -        | 本地模拟以太坊主网 |
| hardhatOp      | -        | 本地模拟 OP 链     |
| localhost      | 31337    | 本地 Hardhat 节点  |
| sepolia        | 11155111 | Sepolia 测试网     |

## 安全特性

### YiDengToken

- ✅ 权限控制（Ownable）
- ✅ 输入验证
- ✅ 事件记录
- ✅ OpenZeppelin 标准库

### YiDengNFT

- ✅ 安全铸造（\_safeMint）
- ✅ URI 存储
- ✅ ERC721 标准兼容
- ✅ 权限隔离

### YiDengDAO

- ✅ 质押机制
- ✅ 一人一票防止垄断
- ✅ 完整输入验证
- ✅ 事件追踪

### CourseManage

- ✅ 重入攻击防护（ReentrancyGuard）
- ✅ CEI 模式
- ✅ 权限控制
- ✅ 状态管理

## 注意事项

⚠️ **重要提示**:

1. **YiDengToken**:

   - 合约会锁定接收到的 ETH，没有提取功能
   - 兑换时直接铸造新代币，理论上可以无限增发
   - 建议在主网部署前进行安全审计

2. **YiDengNFT**:

   - TokenId 从 0 开始连续递增，不可重用
   - URI 一旦设置无法修改
   - 元数据需存储在 IPFS 或其他服务器

3. **YiDengDAO**:

   - 创建提案前必须授权合约转移质押代币
   - 执行提案前合约必须有足够代币用于奖励
   - 投票期固定为 7 天
   - 投票者众多时执行提案 Gas 费用较高

4. **CourseManage**:
   - 课程 ID 必须由后端生成（推荐 UUID）
   - 学生购买前必须先授权合约使用 YD 代币
   - 合约不持有资金，代币直接转给讲师和平台
   - 分成比例固定，不支持动态调整

## 经济模型

详细的代币经济模型设计请参考: [YD 币经济模型设计.md](docs/YD币经济模型设计.md)

核心要点:

- 总供应量: 1000 万 YD
- 初始流动性: 100 万美元（Uniswap）
- 销毁机制: 每月将协议收入的 30% 用于回购销毁
- 应用场景: 购买课程、DAO 治理、激励机制

## 开发工具

### 格式化代码

```bash
npx prettier --write 'contracts/**/*.sol'
```

### 查看合约大小

```bash
npx hardhat size-contracts
```

### 生成文档

```bash
npx hardhat docgen
```

## 常见问题

### Q: 如何更改 YD 代币的兑换比例？

A: 合约所有者调用 `setExchangeRate(uint256 _newRate)` 函数。

### Q: DAO 提案如何判定通过？

A: 赞成票数 > 反对票数即为通过。

### Q: 课程价格可以修改吗？

A: 不可以。课程价格一旦上链不可修改，如需调整需重新注册新课程。

### Q: 合约是否支持升级？

A: 当前合约不支持升级。如需升级功能，建议使用代理模式重新部署。

## 版本历史

- **v1.0**: 初始版本
  - YiDengToken: ETH 兑换功能
  - YiDengNFT: NFT 铸造和管理
  - YiDengDAO: 一人一票治理
  - CourseManage: 课程注册和购买

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 相关链接

- [Hardhat 文档](https://hardhat.org/docs)
- [OpenZeppelin 文档](https://docs.openzeppelin.com/)
- [Solidity 文档](https://docs.soliditylang.org/)
- [Ethers.js 文档](https://docs.ethers.io/)

## 联系方式

如有问题或建议，请通过以下方式联系：

- GitHub Issues
- Discord 社区
- Email

---

**免责声明**: 本项目仅供学习和研究使用，未经过完整的安全审计，请勿直接用于生产环境。
