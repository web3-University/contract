# CourseDAO 部署脚本总结

## 📋 已创建的文件

### 1. 部署脚本
- **[scripts/deploy-course-dao.ts](scripts/deploy-course-dao.ts)**
  - 主要的 CourseDAO 合约部署脚本
  - 支持本地测试网和 Sepolia 测试网
  - 自动部署 Mock 合约（用于测试）
  - 支持合约验证
  - 自动保存部署信息到 `deployments/` 目录

### 2. 交互脚本
- **[scripts/interact-course-dao.ts](scripts/interact-course-dao.ts)**
  - 用于与已部署的 CourseDAO 合约交互
  - 查看 DAO 配置和统计信息
  - 查看提案详情
  - 测试创建提案和投票功能

### 3. 快速测试脚本
- **[scripts/quick-test-dao.ts](scripts/quick-test-dao.ts)**
  - 完整的端到端测试流程
  - 自动部署所有依赖合约
  - 模拟完整的提案创建、投票、结束和奖励领取流程
  - 适合快速验证合约功能

### 4. Mock 测试合约
- **[contracts/mocks/MockERC20.sol](contracts/mocks/MockERC20.sol)**
  - 用于测试的 ERC20 代币合约
  - 支持铸造和销毁功能

- **[contracts/mocks/MockCourseContract.sol](contracts/mocks/MockCourseContract.sol)**
  - 用于测试的课程合约 Mock
  - 实现 ICourseContract 接口
  - 支持创建测试课程和设置学生数量

### 5. 文档
- **[scripts/DEPLOY_README.md](scripts/DEPLOY_README.md)**
  - 详细的部署指南
  - 环境配置说明
  - 部署后配置步骤
  - 常见问题解答

- **[.env.example](.env.example)**
  - 环境变量配置示例
  - 已添加 CourseDAO 相关配置项

- **[package.json](package.json)**
  - 已添加 npm scripts 快捷命令

## 🚀 快速开始

### 安装依赖
```bash
npm install
```

### 方式 1: 快速测试（推荐）
```bash
# 运行完整的测试流程
npm run test:dao
```

### 方式 2: 本地部署
```bash
# 启动本地节点
npm run node

# 在新终端中部署
npm run deploy:dao:local
```

### 方式 3: 测试网部署
```bash
# 1. 配置 .env 文件
cp .env.example .env
# 编辑 .env，填写必要的配置

# 2. 部署到 Sepolia
npm run deploy:dao:sepolia
```

### 与合约交互
```bash
# 设置环境变量
export COURSE_DAO_ADDRESS=0x...

# 运行交互脚本
npm run interact:dao
```

## 📝 部署流程说明

### 1. 本地/Hardhat 网络
当部署到本地网络且未配置依赖合约地址时，脚本会自动：
1. 部署 MockERC20 (YD Token)
2. 部署 MockCourseContract (课程合约)
3. 部署 CourseDAO

### 2. 测试网部署
部署到测试网需要提前部署或配置：
1. YD Token 合约地址 (`YD_TOKEN_ADDRESS`)
2. Course Contract 合约地址 (`COURSE_CONTRACT_ADDRESS`)
3. 然后部署 CourseDAO

### 3. 部署输出
部署成功后，脚本会：
- 显示所有合约地址
- 显示 DAO 初始配置
- 保存部署信息到 JSON 文件
- （可选）在区块链浏览器上验证合约

## 🔧 DAO 默认配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| proposalDeposit | 1000 YD | 创建提案所需押金 |
| minVotingPower | 100 YD | 参与投票最小代币数 |
| votingPeriod | 7 天 | 投票持续时间 |
| quorumPercentage | 10% | 法定人数比例 |
| passThreshold | 50% | 提案通过所需反对票比例 |
| rewardPoolPercentage | 80% | 失败方代币进入奖励池的比例 |

## 📂 项目结构

```
contract/
├── contracts/
│   ├── CourseDAO.sol              # 主合约
│   ├── interfaces/
│   │   ├── ICourseDAO.sol
│   │   ├── IERC20.sol
│   │   └── ICourseContract.sol
│   └── mocks/
│       ├── MockERC20.sol          # Mock ERC20 代币
│       └── MockCourseContract.sol # Mock 课程合约
├── scripts/
│   ├── deploy-course-dao.ts       # 部署脚本
│   ├── interact-course-dao.ts     # 交互脚本
│   ├── quick-test-dao.ts          # 快速测试脚本
│   └── DEPLOY_README.md           # 部署文档
├── deployments/                   # 部署信息存储目录
├── .env.example                   # 环境变量示例
├── package.json                   # npm 配置（含快捷脚本）
└── hardhat.config.ts              # Hardhat 配置
```

## 💡 使用示例

### 创建提案
```typescript
const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);
const tx = await courseDAO.createProposal(
  1,  // courseId
  "课程质量不符合标准"  // reason
);
await tx.wait();
```

### 投票
```typescript
const proposalId = 1;
const voteOption = 1; // 0 = 支持, 1 = 反对
const votingPower = ethers.parseEther("1000");

await courseDAO.vote(proposalId, voteOption, votingPower);
```

### 结束投票
```typescript
await courseDAO.finalizeProposal(proposalId);
```

### 领取奖励
```typescript
await courseDAO.claimReward(proposalId);
```

## 🔍 查询功能

### 查看 DAO 配置
```typescript
const config = await courseDAO.getDAOConfig();
```

### 查看提案信息
```typescript
const proposal = await courseDAO.getProposal(proposalId);
```

### 查看投票统计
```typescript
const stats = await courseDAO.getVoteStats();
```

### 查看所有提案
```typescript
const proposalIds = await courseDAO.getAllProposals();
```

### 检查是否可以投票
```typescript
const canVote = await courseDAO.canVote(userAddress, proposalId);
```

### 计算奖励
```typescript
const reward = await courseDAO.calculateReward(userAddress, proposalId);
```

## ⚙️ 管理功能

### 更新 DAO 配置
```typescript
await courseDAO.updateDAOConfig(
  ethers.parseEther("500"),  // proposalDeposit
  ethers.parseEther("50"),   // minVotingPower
  7 * 24 * 60 * 60,          // votingPeriod
  500,                        // quorumPercentage (5%)
  5000,                       // passThreshold (50%)
  8000                        // rewardPoolPercentage (80%)
);
```

### 暂停/恢复合约
```typescript
await courseDAO.pause();    // 暂停
await courseDAO.unpause();  // 恢复
```

### 转移管理员权限
```typescript
await courseDAO.transferAdmin(newAdminAddress);
```

## 🧪 测试脚本输出示例

运行 `npm run test:dao` 后，你会看到类似以下的输出：

```
==================== CourseDAO 快速测试 ====================

测试账户:
  Deployer: 0x...
  User1: 0x...
  User2: 0x...
  User3: 0x...

==================== 步骤 1: 部署合约 ====================
✓ YD Token: 0x...
✓ Course Contract: 0x...
✓ CourseDAO: 0x...

==================== 步骤 2: 创建测试课程 ====================
✓ 创建课程 ID: 1
✓ 设置课程学生数: 100

==================== 步骤 3: 分配代币给用户 ====================
✓ 0x... 余额: 5000.0 YD
✓ 0x... 余额: 3000.0 YD
✓ 0x... 余额: 2000.0 YD

==================== 步骤 4: 创建提案 ====================
✓ 提案创建成功, ID: 1

==================== 步骤 5: 多账户投票 ====================
✓ User1 投票: 1000.0 YD (反对)
✓ User2 投票: 800.0 YD (反对)
✓ User3 投票: 500.0 YD (支持)

==================== 步骤 6: 结束投票 ====================
✓ 投票已结束
最终结果:
  状态: Succeeded
  支持票: 500.0 YD
  反对票: 1800.0 YD
  奖励池: 1400.0 YD

==================== 步骤 7: 领取奖励 ====================
✓ User1 实际获得: 1777.77 YD
✓ User2 实际获得: 1422.22 YD
✓ User3 实际获得: 500.0 YD (本金)

==================== 测试完成 ====================
```

## 📌 注意事项

1. **私钥安全**: 永远不要将私钥提交到 Git 仓库
2. **测试网代币**: 确保测试账户有足够的测试网 ETH
3. **授权代币**: 用户需要先授权 CourseDAO 合约才能创建提案或投票
4. **投票期限**: 提案创建后需要等待投票期结束才能结束投票
5. **法定人数**: 提案需要达到法定人数才能通过

## 🛠️ 故障排查

### 问题：部署时提示找不到依赖合约
**解决方案**:
- 使用本地网络会自动部署 Mock 合约
- 或在 `.env` 中配置 `YD_TOKEN_ADDRESS` 和 `COURSE_CONTRACT_ADDRESS`

### 问题：合约验证失败
**解决方案**:
- 检查 `.env` 中的 `ETHERSCAN_API_KEY` 是否正确
- 确保等待足够的区块确认（默认 5 个）
- 检查网络连接

### 问题：交易失败 - 授权不足
**解决方案**:
```typescript
const ydToken = await ethers.getContractAt("IERC20", YD_TOKEN_ADDRESS);
await ydToken.approve(COURSE_DAO_ADDRESS, ethers.parseEther("10000"));
```

## 🔗 相关资源

- [Hardhat 文档](https://hardhat.org/docs)
- [OpenZeppelin 合约](https://docs.openzeppelin.com/contracts)
- [Ethers.js 文档](https://docs.ethers.org/)
- [Solidity 文档](https://docs.soliditylang.org/)

## 📄 许可证

MIT License
