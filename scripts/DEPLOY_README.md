# CourseDAO 部署指南

本文档介绍如何部署和使用 CourseDAO 合约。

## 目录

- [环境准备](#环境准备)
- [本地部署](#本地部署)
- [测试网部署](#测试网部署)
- [部署后配置](#部署后配置)
- [常见问题](#常见问题)

## 环境准备

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# Sepolia 测试网配置
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
SEPOLIA_PRIVATE_KEY=your_private_key_here

# Etherscan API (用于验证合约)
ETHERSCAN_API_KEY=your_etherscan_api_key

# 依赖合约地址 (如果已部署)
YD_TOKEN_ADDRESS=0x...
COURSE_CONTRACT_ADDRESS=0x...

# 是否验证合约
VERIFY=true
```

## 本地部署

### 方式 1: 使用 Hardhat 本地节点

1. 启动本地节点：

```bash
npx hardhat node
```

2. 在新终端中部署：

```bash
npx hardhat run scripts/deploy-course-dao.ts --network localhost
```

这将自动部署所需的 Mock 合约（YD Token 和 Course Contract）以及 CourseDAO 合约。

### 方式 2: 直接在 Hardhat 网络部署

```bash
npx hardhat run scripts/deploy-course-dao.ts --network hardhat
```

## 测试网部署

### 前提条件

在部署到测试网之前，需要先部署依赖合约：

1. **YD Token 合约** - ERC20 代币
2. **Course Contract 合约** - 课程管理合约

### 部署步骤

1. 确保已在 `.env` 中配置了依赖合约地址：

```bash
YD_TOKEN_ADDRESS=0x1234...
COURSE_CONTRACT_ADDRESS=0x5678...
```

2. 部署到 Sepolia 测试网：

```bash
npx hardhat run scripts/deploy-course-dao.ts --network sepolia
```

### 部署输出

部署成功后，脚本会输出：

```
==================== 部署完成 ====================

已部署合约:
  CourseDAO: 0xABCD...
  YD Token: 0x1234...
  Course Contract: 0x5678...

下一步操作:
1. 确保 YD Token 已分配给用户
2. 确保用户已授权 CourseDAO 合约使用 YD Token
3. (可选) 更新 DAO 配置
4. 开始创建提案
```

### 部署信息保存

部署信息会自动保存到 `deployments/` 目录：

```
deployments/course-dao-sepolia-1234567890.json
```

文件内容包括：
- 网络信息
- 合约地址
- DAO 配置参数
- 部署交易哈希

## 部署后配置

### 1. 分配 YD Token

用户需要持有 YD Token 才能参与投票：

```typescript
const ydToken = await ethers.getContractAt("IERC20", YD_TOKEN_ADDRESS);
await ydToken.transfer(userAddress, ethers.parseEther("10000"));
```

### 2. 授权 CourseDAO 使用代币

用户需要授权 CourseDAO 合约：

```typescript
const ydToken = await ethers.getContractAt("IERC20", YD_TOKEN_ADDRESS);
await ydToken.approve(COURSE_DAO_ADDRESS, ethers.parseEther("100000"));
```

### 3. (可选) 更新 DAO 配置

管理员可以更新 DAO 配置：

```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);

await courseDAO.updateDAOConfig(
  ethers.parseEther("500"),  // proposalDeposit: 500 YD
  ethers.parseEther("50"),   // minVotingPower: 50 YD
  7 * 24 * 60 * 60,          // votingPeriod: 7 days
  500,                        // quorumPercentage: 5%
  5000,                       // passThreshold: 50%
  8000                        // rewardPoolPercentage: 80%
);
```

### 4. 创建提案

```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);

const courseId = 1;
const reason = "课程质量不符合标准，内容过时且讲解不清晰";

const tx = await courseDAO.createProposal(courseId, reason);
await tx.wait();
```

### 5. 投票

```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);

const proposalId = 1;
const voteOption = 1; // 0 = For, 1 = Against
const votingPower = ethers.parseEther("1000");

const tx = await courseDAO.vote(proposalId, voteOption, votingPower);
await tx.wait();
```

### 6. 结束投票

```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);

const proposalId = 1;
const tx = await courseDAO.finalizeProposal(proposalId);
await tx.wait();
```

### 7. 领取奖励

```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);

const proposalId = 1;
const tx = await courseDAO.claimReward(proposalId);
await tx.wait();
```

## DAO 配置参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| proposalDeposit | 1000 YD | 创建提案需要的押金 |
| minVotingPower | 100 YD | 参与投票的最小代币数量 |
| votingPeriod | 7 天 | 投票持续时间 |
| quorumPercentage | 10% | 法定人数比例 |
| passThreshold | 50% | 提案通过所需的反对票比例 |
| rewardPoolPercentage | 80% | 失败方代币进入奖励池的比例 |

## 常见问题

### Q: 部署时提示找不到依赖合约怎么办？

A: 有两种解决方案：

1. 使用本地测试网，脚本会自动部署 Mock 合约
2. 在 `.env` 文件中设置 `YD_TOKEN_ADDRESS` 和 `COURSE_CONTRACT_ADDRESS`

### Q: 如何查看部署的合约地址？

A: 查看 `deployments/` 目录下的 JSON 文件，或在部署输出中查找。

### Q: 合约验证失败怎么办？

A: 确保：

1. `.env` 中配置了正确的 `ETHERSCAN_API_KEY`
2. 网络连接正常
3. 等待足够的区块确认（默认 5 个区块）

### Q: 如何在浏览器上查看合约？

A: 部署后访问：

- Sepolia: `https://sepolia.etherscan.io/address/YOUR_CONTRACT_ADDRESS`
- 其他网络请查看对应的区块浏览器

### Q: 如何测试合约功能？

A: 可以编写测试文件或使用 Hardhat Console：

```bash
npx hardhat console --network localhost
```

然后在控制台中交互：

```javascript
const courseDAO = await ethers.getContractAt("CourseDAO", "0x...");
const config = await courseDAO.getDAOConfig();
console.log(config);
```

## 相关文件

- 部署脚本: `scripts/deploy-course-dao.ts`
- 主合约: `contracts/CourseDAO.sol`
- Mock 合约: `contracts/mocks/`
- 部署记录: `deployments/`

## 更多资源

- [Hardhat 文档](https://hardhat.org/docs)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts)
- [Ethers.js 文档](https://docs.ethers.org/)
