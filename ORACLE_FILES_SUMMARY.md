# Chainlink Functions 预言机系统 - 文件清单

## 已创建的文件

本预言机系统包含以下文件，用于实现基于 Chainlink Functions 的课程完成验证和自动 NFT 铸造功能。

### 1. 核心合约

#### `contracts/CourseNFTOracle.sol`
- **功能**: 主预言机回调合约
- **职责**:
  - 接收课程完成验证请求
  - 调用 Chainlink Functions 执行链下验证
  - 接收预言机回调
  - 自动铸造 NFT 证书
- **关键特性**:
  - 单个和批量请求支持
  - 可配置的 JavaScript 源代码
  - 完整的请求状态管理
  - 事件日志追踪

#### `contracts/tokens/SimpleYDNFT.sol`
- **功能**: NFT 证书合约（已存在）
- **说明**: 预言机合约会调用此合约的 `mintCertificate` 函数

### 2. Chainlink Functions 源代码

#### `chainlink-functions-source.js`
- **功能**: 链下执行的 JavaScript 代码示例
- **包含方案**:
  - 方案 1: 调用单个 REST API
  - 方案 2: 调用多个 API 进行交叉验证
  - 方案 3: 带认证的 API 调用（使用 secrets）
  - 方案 4: 调用链上合约数据
- **用途**: 
  - 部署时嵌入合约
  - 可通过 `updateSource` 函数更新

### 3. 部署和交互脚本

#### `scripts/deploy-oracle.js`
- **功能**: 完整的部署脚本
- **执行步骤**:
  1. 部署 NFT 合约
  2. 部署预言机合约
  3. 转移 NFT 所有权
  4. （可选）验证合约
  5. 保存部署信息
- **支持网络**:
  - Sepolia 测试网
  - Polygon Mumbai 测试网
  - Avalanche Fuji 测试网

#### `scripts/interact-oracle.js`
- **功能**: 合约交互脚本
- **包含功能**:
  - 请求单个课程验证
  - 批量请求课程验证
  - 查询请求状态
  - 查询学生 NFT
  - 更新源代码
  - 查看合约配置
  - 监听事件

### 4. 测试文件

#### `test/CourseNFTOracle.test.js`
- **功能**: 完整的单元测试套件
- **测试覆盖**:
  - 合约部署测试
  - 请求功能测试
  - 批量请求测试
  - 查询功能测试
  - 管理员功能测试
  - 权限控制测试
  - 边界条件测试

### 5. 文档

#### `ORACLE_README.md`
- **功能**: 系统概览和快速开始指南
- **内容**:
  - 系统架构
  - 快速开始指南
  - 工作流程图
  - 合约接口文档
  - 成本分析
  - 安全考虑
  - 监控和维护
  - 故障排查
  - 最佳实践

#### `ORACLE_DEPLOYMENT_GUIDE.md`
- **功能**: 详细的部署指南
- **内容**:
  - 前置准备
  - 网络配置
  - 详细部署步骤
  - 使用方法示例
  - 事件监听
  - 后端 API 实现示例
  - 测试指南
  - 成本估算
  - 安全注意事项
  - 故障排查

#### `ORACLE_FILES_SUMMARY.md`
- **功能**: 本文件，文件清单和使用流程

### 6. 配置文件

#### `.env.example`
- **功能**: 环境变量配置示例
- **包含配置**:
  - 网络 RPC URLs
  - Chainlink Functions 订阅 ID
  - 私钥配置
  - NFT 元数据 URI
  - API 密钥
  - 区块链浏览器 API 密钥

## 使用流程

### 第一步：环境准备

```bash
# 1. 复制环境变量配置
cp .env.example .env

# 2. 编辑 .env 文件，填入实际配置
# - RPC URLs
# - Chainlink Functions Subscription ID
# - 私钥
# - 其他必要配置

# 3. 安装依赖
npm install @chainlink/contracts
```

### 第二步：部署合约

```bash
# 部署到 Sepolia 测试网
npx hardhat run scripts/deploy-oracle.js --network sepolia

# 记录输出的合约地址
# NFT Contract: 0x...
# Oracle Contract: 0x...
```

### 第三步：配置 Chainlink Functions

1. 访问 https://functions.chain.link/
2. 选择对应网络的订阅
3. 点击 "Add Consumer"
4. 输入 Oracle 合约地址
5. 确认交易

### 第四步：测试系统

```bash
# 1. 更新 .env 文件中的合约地址
ORACLE_ADDRESS=0x...
NFT_ADDRESS=0x...

# 2. 运行交互脚本
npx hardhat run scripts/interact-oracle.js --network sepolia

# 3. 运行单元测试
npx hardhat test test/CourseNFTOracle.test.js
```

### 第五步：集成到应用

```javascript
// 前端或后端代码示例
const oracle = new ethers.Contract(
  ORACLE_ADDRESS,
  oracleABI,
  signer
);

// 请求验证
const tx = await oracle.requestCourseCompletion(
  studentAddress,
  courseId,
  courseName
);

// 监听结果
oracle.on("RequestFulfilled", (requestId, student, courseId, success, tokenId) => {
  if (success) {
    console.log(`NFT #${tokenId} minted!`);
  }
});
```

## 后端 API 开发

根据你选择的 JavaScript 方案，开发相应的后端 API：

### 基本 API 端点

```
GET /courses/{courseId}/students/{studentAddress}/completion

Response:
{
  "completed": true,
  "completedAt": "2024-01-15T10:30:00Z",
  "progress": 100
}
```

参考 `ORACLE_DEPLOYMENT_GUIDE.md` 中的后端 API 实现示例。

## 目录结构

```
contract/
├── contracts/
│   ├── CourseNFTOracle.sol          # 预言机合约 ⭐
│   ├── tokens/
│   │   └── SimpleYDNFT.sol          # NFT 合约
│   └── interfaces/
│       └── IERC721.sol
│
├── scripts/
│   ├── deploy-oracle.js             # 部署脚本 ⭐
│   └── interact-oracle.js           # 交互脚本 ⭐
│
├── test/
│   └── CourseNFTOracle.test.js      # 测试文件 ⭐
│
├── deployments/                      # 部署记录（自动生成）
│   └── sepolia-*.json
│
├── chainlink-functions-source.js     # JS 源代码 ⭐
├── ORACLE_README.md                  # 系统概览 ⭐
├── ORACLE_DEPLOYMENT_GUIDE.md        # 部署指南 ⭐
├── ORACLE_FILES_SUMMARY.md           # 本文件 ⭐
└── .env.example                      # 环境变量示例 ⭐

⭐ = 新创建的文件
```

## 关键配置参数

### Chainlink Functions 网络配置

| 网络 | Router 地址 | DON ID | LINK Token |
|------|------------|--------|------------|
| Sepolia | `0xb83E47C2bC239B3bf370bc41e1459A34b41238D0` | `fun-ethereum-sepolia-1` | `0x779877A7B0D9E8603169DdbD7836e478b4624789` |
| Mumbai | `0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C` | `fun-polygon-mumbai-1` | `0x326C977E6efc84E512bB9C30f76E30c160eD06FB` |
| Fuji | `0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0` | `fun-avalanche-fuji-1` | `0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846` |

### Gas Limit 建议

- 简单验证: 200,000 gas
- 复杂验证 + NFT 铸造: 300,000 gas
- 包含复杂逻辑: 400,000 gas

## 成本估算

### 一次性成本（部署）
- NFT 合约: ~$10-50
- Oracle 合约: ~$15-75
- **总计**: ~$25-125（取决于 gas 价格）

### 运营成本（每次使用）
- Gas 费: ~$1-5/请求
- LINK 费: ~0.1-0.5 LINK/请求（约 $1-5）
- **总计**: ~$2-10/请求

### 批量优化
- 批量 10 个请求可节省约 30% gas

## 监控和维护检查清单

- [ ] LINK 余额充足（建议 > 10 LINK）
- [ ] Consumer 已添加到订阅
- [ ] NFT 合约 owner 是 Oracle 合约
- [ ] 后端 API 正常响应
- [ ] 事件日志正常
- [ ] 定期检查请求成功率

## 常见问题速查

| 问题 | 检查项 | 解决方法 |
|------|--------|----------|
| 请求失败 | LINK 余额 | 充值 LINK |
| 回调未执行 | Consumer 列表 | 添加 Consumer |
| API 超时 | API 响应时间 | 优化 API |
| NFT 铸造失败 | 合约权限 | 检查 ownership |

## 下一步计划

1. **生产环境部署**
   - 主网部署前充分测试
   - 准备足够的 LINK
   - 配置监控告警

2. **功能扩展**
   - 支持更多验证逻辑
   - 添加多签管理
   - 实现紧急暂停机制

3. **优化**
   - 批量处理优化
   - Gas 优化
   - 缓存机制

## 支持资源

- **Chainlink 官方文档**: https://docs.chain.link/chainlink-functions
- **Chainlink Discord**: https://discord.gg/chainlink
- **问题反馈**: 提交 GitHub Issue

---

**版本**: 1.0.0  
**最后更新**: 2024-10-18  
**作者**: Web3 University Team  
**许可证**: MIT
