# CourseDAO Ignition 部署指南

本目录包含使用 Hardhat Ignition 部署 CourseDAO 合约的模块。

## 📁 模块文件

- **MockContracts.ts** - 部署测试用的 Mock 合约 (YD Token 和 Course Contract)
- **CourseDAO.ts** - 部署 CourseDAO 治理合约
- **SimpleYDToken.ts** - 部署 SimpleYD Token 合约
- **CourseContract.ts** - 部署课程合约
- **SimpleYDNFT.ts** - 部署课程证书 NFT 合约

## 🚀 部署方式

### 1. 本地测试网络 (完整部署)

如果是第一次部署，需要先部署 Mock 合约，然后部署 CourseDAO：

```bash
# 启动本地节点
npm run node

# 在新终端中执行完整部署
npm run deploy:dao:full
```

或者分步执行：

```bash
# 步骤 1: 部署 Mock 合约
npm run deploy:dao:mock

# 步骤 2: 部署 CourseDAO
npm run deploy:dao:local
```

### 2. 使用现有合约地址

如果已经有 YD Token 和 Course Contract 地址，可以直接部署 CourseDAO：

#### 方式 A: 使用环境变量

```bash
export YD_TOKEN_ADDRESS="0x..."
export COURSE_CONTRACT_ADDRESS="0x..."
npm run deploy:dao:local
```

#### 方式 B: 使用参数传入

```bash
npx hardhat ignition deploy ./ignition/modules/CourseDAO.ts --network localhost \
  --parameters '{"CourseDAOModule":{"ydTokenAddress":"0x...","courseContractAddress":"0x..."}}'
```

### 3. Sepolia 测试网部署

```bash
# 使用环境变量
export YD_TOKEN_ADDRESS="0x..."
export COURSE_CONTRACT_ADDRESS="0x..."
npm run deploy:dao:sepolia

# 或使用参数
npx hardhat ignition deploy ./ignition/modules/CourseDAO.ts --network sepolia \
  --parameters '{"CourseDAOModule":{"ydTokenAddress":"0x...","courseContractAddress":"0x..."}}'
```

## 📋 部署记录

部署完成后，合约地址会保存在：
```
ignition/deployments/chain-{chainId}/deployed_addresses.json
```

例如：
- 本地网络: `chain-31337/deployed_addresses.json`
- Sepolia: `chain-11155111/deployed_addresses.json`

## 🔍 查看部署信息

```bash
# 查看本地网络的部署地址
cat ignition/deployments/chain-31337/deployed_addresses.json

# 查看 Sepolia 的部署地址
cat ignition/deployments/chain-11155111/deployed_addresses.json
```

## 🛠️ 查看合约配置

部署完成后，可以通过 Hardhat Console 查看合约配置：

```bash
npx hardhat console --network localhost
```

在控制台中：

```javascript
// 读取部署地址
const deployed = require('./ignition/deployments/chain-31337/deployed_addresses.json');
const courseDaoAddress = deployed['CourseDAOModule#CourseDAO'];

// 获取合约实例
const CourseDAO = await ethers.getContractFactory('CourseDAO');
const courseDAO = await CourseDAO.attach(courseDaoAddress);

// 查看 DAO 配置
const config = await courseDAO.getDAOConfig();
console.log('提案押金:', ethers.formatEther(config.proposalDeposit), 'YD');
console.log('最小投票权:', ethers.formatEther(config.minVotingPower), 'YD');
console.log('投票期限:', Number(config.votingPeriod) / 86400, '天');
console.log('法定人数比例:', Number(config.quorumPercentage) / 100, '%');
console.log('通过阈值:', Number(config.passThreshold) / 100, '%');

// 查看管理员
const admin = await courseDAO.admin();
console.log('管理员:', admin);
```

## 📝 与旧部署脚本的对比

### 旧方式 (scripts/deploy-course-dao.ts)
```bash
npx hardhat run scripts/deploy-course-dao.ts --network localhost
```

### 新方式 (Ignition)
```bash
npm run deploy:dao:full
# 或
npm run deploy:dao:local
```

## ✨ Ignition 的优势

1. **声明式部署** - 使用声明式语法，更清晰易懂
2. **依赖管理** - 自动处理合约之间的依赖关系
3. **可重复部署** - 支持增量部署，避免重复部署已部署的合约
4. **部署记录** - 自动保存部署记录，便于追踪
5. **参数化配置** - 支持通过参数和环境变量灵活配置
6. **网络隔离** - 不同网络的部署记录自动隔离

## 🔧 故障排查

### 问题 1: "缺少必要的合约地址"

**解决方案**:
1. 先运行 `npm run deploy:dao:mock` 部署 Mock 合约
2. 或者设置环境变量 `YD_TOKEN_ADDRESS` 和 `COURSE_CONTRACT_ADDRESS`

### 问题 2: "找不到部署记录"

**解决方案**:
确保已经部署过 MockContracts 模块，检查 `ignition/deployments/chain-{chainId}/deployed_addresses.json` 文件是否存在。

### 问题 3: 需要重新部署

**解决方案**:
Ignition 默认会跳过已部署的合约。如需重新部署：
```bash
# 删除部署记录
rm -rf ignition/deployments/chain-31337

# 重新部署
npm run deploy:dao:full
```

## 📚 相关文档

- [Hardhat Ignition 官方文档](https://hardhat.org/ignition/docs/getting-started)
- [CourseDAO 合约文档](../../contracts/CourseDAO.sol)

## ⚠️ 注意事项

1. **本地测试** - 在 localhost 或 hardhat 网络上，会自动使用 Mock 合约
2. **测试网部署** - 在 Sepolia 等测试网上，必须提供真实的合约地址
3. **主网部署** - 部署到主网前，请确保充分测试并审计所有合约
4. **私钥安全** - 永远不要将私钥提交到版本控制系统
5. **Gas 费用** - 部署前确保账户有足够的 ETH 支付 Gas 费用
