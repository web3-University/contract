# 🚀 快速开始指南

本指南帮助你在 5 分钟内理解和部署 Chainlink Functions 预言机系统。

## 📋 前置条件检查清单

- [ ] 已安装 Node.js (v16+)
- [ ] 已安装 Hardhat 或 Foundry
- [ ] 拥有测试网钱包（包含测试 ETH）
- [ ] 拥有 Chainlink Functions 订阅 ID
- [ ] 订阅中有至少 5 LINK 代币

## 🎯 系统概览

**这个系统做什么？**
当学生完成课程时，系统自动:
1. 调用后端 API 验证课程完成状态
2. 通过 Chainlink 预言机获取验证结果
3. 自动为学生铸造 NFT 课程证书

**核心文件**:
- `contracts/CourseNFTOracle.sol` - 预言机合约
- `contracts/tokens/SimpleYDNFT.sol` - NFT 合约
- `scripts/deploy-oracle.js` - 部署脚本
- `scripts/interact-oracle.js` - 交互脚本

## ⚡ 3 步快速部署

### 步骤 1: 配置环境 (1 分钟)

```bash
# 1. 复制环境变量配置
cp .env.example .env

# 2. 编辑 .env，填入你的配置
nano .env
```

**必填项**:
```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
SEPOLIA_SUBSCRIPTION_ID=12345  # 你的 Chainlink 订阅 ID
PRIVATE_KEY=0x...              # 你的私钥
```

### 步骤 2: 安装依赖 (1 分钟)

```bash
npm install @chainlink/contracts
```

### 步骤 3: 部署合约 (3 分钟)

```bash
# 部署到 Sepolia 测试网
npx hardhat run scripts/deploy-oracle.js --network sepolia

# 输出示例:
# NFT Contract deployed to: 0xABC...
# Oracle Contract deployed to: 0xDEF...
```

**重要**: 记录输出的合约地址！

## 🔗 配置 Chainlink Functions

### 在线配置 (2 分钟)

1. 访问 https://functions.chain.link/
2. 连接钱包
3. 选择你的订阅
4. 点击 "Add Consumer"
5. 粘贴 Oracle 合约地址
6. 确认交易

✅ 完成！系统已准备就绪。

## 🧪 测试系统

### 快速测试

```bash
# 更新 .env 文件
ORACLE_ADDRESS=0xYourOracleAddress
NFT_ADDRESS=0xYourNFTAddress

# 运行测试脚本
npx hardhat run scripts/interact-oracle.js --network sepolia
```

### 单元测试

```bash
npx hardhat test test/CourseNFTOracle.test.js
```

## 📝 使用示例

### JavaScript/TypeScript

```javascript
const { ethers } = require("ethers");

// 连接合约
const oracle = new ethers.Contract(
  ORACLE_ADDRESS,
  CourseNFTOracleABI,
  signer
);

// 请求验证
const tx = await oracle.requestCourseCompletion(
  "0xStudentAddress",
  101,                    // 课程 ID
  "区块链基础课程"
);

console.log("Request sent:", tx.hash);

// 监听结果
oracle.on("RequestFulfilled", (requestId, student, courseId, success, tokenId) => {
  if (success) {
    console.log(`🎉 NFT #${tokenId} 已铸造给学生 ${student}`);
  } else {
    console.log("❌ 验证失败");
  }
});
```

### 后端 API（必需）

你的后端需要提供此 API:

```javascript
// GET /courses/:courseId/students/:address/completion

app.get('/courses/:courseId/students/:address/completion', (req, res) => {
  const { courseId, address } = req.params;

  // 从数据库查询
  const student = db.getStudent(address, courseId);

  res.json({
    completed: student.completedAt !== null,
    completedAt: student.completedAt,
    progress: student.progress
  });
});
```

## 🎨 前端集成

### React 示例

```jsx
import { useContract } from './hooks/useContract';

function RequestCertificate({ studentAddress, courseId }) {
  const oracle = useContract(ORACLE_ADDRESS, OracleABI);
  const [loading, setLoading] = useState(false);

  const handleRequest = async () => {
    setLoading(true);
    try {
      const tx = await oracle.requestCourseCompletion(
        studentAddress,
        courseId,
        "课程名称"
      );
      await tx.wait();
      alert('验证请求已发送，请等待预言机回调');
    } catch (error) {
      console.error(error);
      alert('请求失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <button onClick={handleRequest} disabled={loading}>
      {loading ? '处理中...' : '申请证书'}
    </button>
  );
}
```

## 📊 监控和调试

### 查看请求状态

```javascript
// 获取请求详情
const request = await oracle.getRequest(requestId);

console.log({
  student: request.student,
  courseId: request.courseId.toString(),
  courseName: request.courseName,
  fulfilled: request.fulfilled,
  success: request.success
});
```

### 监听事件

```bash
# 使用 Hardhat console
npx hardhat console --network sepolia

> const oracle = await ethers.getContractAt("CourseNFTOracle", "0x...")
> oracle.on("RequestSent", console.log)
> oracle.on("RequestFulfilled", console.log)
```

## 🔧 常见问题解决

### 问题 1: "Insufficient LINK balance"

**原因**: 订阅中 LINK 余额不足

**解决**:
```bash
# 访问 https://faucets.chain.link/sepolia
# 获取测试 LINK
# 转入你的订阅
```

### 问题 2: 回调未执行

**检查清单**:
- [ ] Oracle 合约已添加为 Consumer
- [ ] 订阅有足够 LINK
- [ ] gas limit 设置合理（建议 300000）

**验证**:
```javascript
// 检查是否是 Consumer
const isConsumer = await subscriptionManager.consumerIsAdded(
  subscriptionId,
  oracleAddress
);
console.log("Is Consumer:", isConsumer);
```

### 问题 3: API 调用失败

**检查**:
- API URL 是否正确
- API 是否返回正确格式
- 是否需要 CORS 配置

**调试 JavaScript**:
```javascript
// 在 Chainlink Functions Playground 测试
// https://functions.chain.link/playground

const response = await Functions.makeHttpRequest({
  url: "https://your-api.com/test",
  method: "GET"
});

console.log(response.data);
```

## 💰 成本参考

### 一次性成本
- 部署: ~$25-125 (取决于 gas 价格)

### 每次使用
- Gas 费: ~$1-5
- LINK 费: ~0.1-0.5 LINK ($1-5)
- **总计**: ~$2-10/请求

### 省钱技巧
- 使用批量请求（节省 30% gas）
- 在 gas 价格低时部署
- 优化 JavaScript 代码以减少执行时间

## 📚 下一步

### 基础使用
- ✅ 完成快速部署
- [ ] 测试单个请求
- [ ] 测试批量请求
- [ ] 集成前端

### 高级功能
- [ ] 自定义 JavaScript 验证逻辑
- [ ] 添加 API 认证
- [ ] 实现多数据源验证
- [ ] 配置监控告警

### 生产准备
- [ ] 安全审计
- [ ] 压力测试
- [ ] 主网部署规划
- [ ] 建立监控系统

## 📖 详细文档

- **系统架构**: [ORACLE_ARCHITECTURE.md](./ORACLE_ARCHITECTURE.md)
- **部署指南**: [ORACLE_DEPLOYMENT_GUIDE.md](./ORACLE_DEPLOYMENT_GUIDE.md)
- **完整文档**: [ORACLE_README.md](./ORACLE_README.md)
- **文件清单**: [ORACLE_FILES_SUMMARY.md](./ORACLE_FILES_SUMMARY.md)

## 🆘 获取帮助

### 官方资源
- [Chainlink Functions 文档](https://docs.chain.link/chainlink-functions)
- [Chainlink Discord](https://discord.gg/chainlink)
- [GitHub Issues](https://github.com/smartcontractkit/chainlink)

### 社区
- [Stack Overflow (chainlink 标签)](https://stackoverflow.com/questions/tagged/chainlink)
- [Chainlink 开发者论坛](https://community.chain.link/)

## ⚠️ 重要提醒

1. **测试网先行**: 永远先在测试网测试
2. **私钥安全**: 永远不要提交私钥到 Git
3. **LINK 余额**: 定期检查订阅余额
4. **API 可靠性**: 确保后端 API 稳定可用
5. **监控告警**: 生产环境必须有监控

---

**准备好了吗？开始部署吧！** 🚀

如有问题，查看详细文档或在社区寻求帮助。
