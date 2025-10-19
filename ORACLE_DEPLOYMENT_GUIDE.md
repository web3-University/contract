# Chainlink Functions 预言机部署和使用指南

## 概述

本项目使用 Chainlink Functions 实现课程完成验证和自动化 NFT 铸造。当学生完成课程后，系统会调用链下 API 验证完成状态，然后通过预言机回调自动为学生铸造课程证书 NFT。

## 架构流程

```
学生完成课程
    ↓
请求课程验证 (requestCourseCompletion)
    ↓
Chainlink DON 执行链下 JavaScript
    ↓
调用后端 API 验证课程完成状态
    ↓
返回验证结果到合约 (fulfillRequest)
    ↓
自动铸造 NFT 证书
```

## 前置准备

### 1. 安装 Chainlink 依赖

```bash
npm install @chainlink/contracts
```

或者使用 Foundry:

```bash
forge install smartcontractkit/chainlink-brownie-contracts
```

### 2. 获取 Chainlink Functions 资源

1. 访问 [Chainlink Functions](https://functions.chain.link/)
2. 连接钱包并创建订阅 (Subscription)
3. 向订阅中充值 LINK 代币
4. 记录以下信息:
   - **Subscription ID**: 你的订阅 ID
   - **Router Address**: Chainlink Functions Router 地址
   - **DON ID**: 去中心化预言机网络 ID

### 3. 网络配置参考

#### Sepolia 测试网

- **Router**: `0xb83E47C2bC239B3bf370bc41e1459A34b41238D0`
- **DON ID**: `fun-ethereum-sepolia-1`
- **LINK Token**: `0x779877A7B0D9E8603169DdbD7836e478b4624789`

#### Polygon Mumbai 测试网

- **Router**: `0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C`
- **DON ID**: `fun-polygon-mumbai-1`
- **LINK Token**: `0x326C977E6efc84E512bB9C30f76E30c160eD06FB`

## 部署步骤

### 步骤 1: 部署 NFT 合约

首先部署 `SimpleYDNFT.sol`:

```solidity
// 部署脚本示例
const SimpleYDNFT = await ethers.getContractFactory("SimpleYDNFT");
const nft = await SimpleYDNFT.deploy("https://api.web3university.com/metadata/");
await nft.deployed();

console.log("NFT Contract deployed to:", nft.address);
```

### 步骤 2: 部署预言机合约

部署 `CourseNFTOracle.sol`:

```javascript
const CourseNFTOracle = await ethers.getContractFactory("CourseNFTOracle");

const oracle = await CourseNFTOracle.deploy(
  "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0", // Router address (Sepolia)
  nft.address,                                    // NFT contract address
  "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000", // DON ID
  12345,                                          // Subscription ID
  300000                                          // Gas limit (300k)
);

await oracle.deployed();
console.log("Oracle Contract deployed to:", oracle.address);
```

### 步骤 3: 授权预言机合约铸造 NFT

将 NFT 合约的所有权转移给预言机合约:

```javascript
await nft.transferOwnership(oracle.address);
console.log("NFT ownership transferred to Oracle");
```

### 步骤 4: 将预言机合约添加到订阅

在 [Chainlink Functions Dashboard](https://functions.chain.link/) 中:

1. 选择你的订阅
2. 点击 "Add Consumer"
3. 输入预言机合约地址
4. 确认交易

或者使用代码:

```javascript
const subscriptionManager = await ethers.getContractAt(
  "FunctionsSubscriptions",
  ROUTER_ADDRESS
);

await subscriptionManager.addConsumer(SUBSCRIPTION_ID, oracle.address);
```

### 步骤 5: 更新 JavaScript 源代码 (可选)

如果需要自定义验证逻辑:

```javascript
const newSource = `
const studentAddress = args[0];
const courseId = args[1];

const response = await Functions.makeHttpRequest({
  url: \`https://your-api.com/verify/\${studentAddress}/\${courseId}\`,
  method: "GET"
});

if (response.error) throw Error("API failed");
return Functions.encodeUint256(response.data.completed ? 1 : 0);
`;

await oracle.updateSource(newSource);
```

## 使用方法

### 单个学生请求

```javascript
// 请求验证学生课程完成状态
const tx = await oracle.requestCourseCompletion(
  "0xStudentAddress",           // 学生地址
  101,                          // 课程 ID
  "区块链基础课程"              // 课程名称
);

const receipt = await tx.wait();

// 从事件中获取 Request ID
const event = receipt.events.find(e => e.event === 'RequestSent');
const requestId = event.args.requestId;

console.log("Request ID:", requestId);
```

### 批量请求

```javascript
const students = [
  "0xStudent1Address",
  "0xStudent2Address",
  "0xStudent3Address"
];

const courseIds = [101, 102, 101];
const courseNames = [
  "区块链基础",
  "智能合约开发",
  "区块链基础"
];

const tx = await oracle.batchRequestCourseCompletion(
  students,
  courseIds,
  courseNames
);

await tx.wait();
```

### 查询请求状态

```javascript
// 获取请求详情
const request = await oracle.getRequest(requestId);

console.log("Student:", request.student);
console.log("Course ID:", request.courseId);
console.log("Fulfilled:", request.fulfilled);
console.log("Success:", request.success);

// 检查是否有待处理的请求
const hasPending = await oracle.hasPendingRequest(
  "0xStudentAddress",
  101
);
```

## 监听事件

### 监听请求发送事件

```javascript
oracle.on("RequestSent", (requestId, student, courseId, courseName) => {
  console.log("Request sent:");
  console.log("  Request ID:", requestId);
  console.log("  Student:", student);
  console.log("  Course:", courseId, "-", courseName);
});
```

### 监听请求完成事件

```javascript
oracle.on("RequestFulfilled", (requestId, student, courseId, success, tokenId) => {
  if (success) {
    console.log(`NFT #${tokenId} minted for student ${student}`);
  } else {
    console.log(`Course verification failed for student ${student}`);
  }
});
```

## 后端 API 实现示例

你的后端 API 应该返回学生的课程完成状态:

### Node.js/Express 示例

```javascript
// GET /courses/:courseId/students/:studentAddress/completion
app.get('/courses/:courseId/students/:studentAddress/completion', async (req, res) => {
  const { courseId, studentAddress } = req.params;

  try {
    // 从数据库查询学生完成状态
    const student = await db.students.findOne({
      address: studentAddress.toLowerCase(),
      courseId: parseInt(courseId)
    });

    const completed = student && student.completedAt !== null;

    res.json({
      completed: completed,
      completedAt: student?.completedAt || null,
      progress: student?.progress || 0
    });
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
});
```

### FastAPI (Python) 示例

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class CompletionStatus(BaseModel):
    completed: bool
    completedAt: Optional[str] = None
    progress: int = 0

@app.get("/courses/{course_id}/students/{student_address}/completion")
async def get_completion_status(course_id: int, student_address: str):
    # 查询数据库
    student = await db.query_student(student_address.lower(), course_id)

    if not student:
        return CompletionStatus(completed=False)

    return CompletionStatus(
        completed=student.completed,
        completedAt=student.completed_at,
        progress=student.progress
    )
```

## 测试

### Hardhat 测试示例

```javascript
const { expect } = require("chai");

describe("CourseNFTOracle", function () {
  let oracle, nft, owner, student;

  beforeEach(async function () {
    [owner, student] = await ethers.getSigners();

    // Deploy NFT
    const NFT = await ethers.getContractFactory("SimpleYDNFT");
    nft = await NFT.deploy("https://api.test.com/");

    // Deploy Oracle
    const Oracle = await ethers.getContractFactory("CourseNFTOracle");
    oracle = await Oracle.deploy(
      ROUTER_ADDRESS,
      nft.address,
      DON_ID,
      SUBSCRIPTION_ID,
      300000
    );

    // Transfer NFT ownership
    await nft.transferOwnership(oracle.address);
  });

  it("Should request course completion", async function () {
    const tx = await oracle.requestCourseCompletion(
      student.address,
      101,
      "Test Course"
    );

    const receipt = await tx.wait();
    const event = receipt.events.find(e => e.event === 'RequestSent');

    expect(event.args.student).to.equal(student.address);
    expect(event.args.courseId).to.equal(101);
  });
});
```

## 成本估算

### Gas 费用

- 请求课程验证: ~150,000 gas
- 批量请求 (10个): ~1,000,000 gas
- 回调铸造 NFT: ~200,000 gas (由 LINK 支付)

### LINK 费用

每次请求大约消耗 0.1-0.5 LINK (取决于网络)

## 安全注意事项

1. **API 安全**: 使用 HTTPS 和 API 密钥认证
2. **数据验证**: 在智能合约中验证所有输入参数
3. **重入保护**: 回调函数中的状态更新
4. **访问控制**: 仅授权地址可以请求验证
5. **订阅管理**: 定期监控 LINK 余额

## 故障排查

### 常见问题

1. **请求失败: "Insufficient LINK balance"**
   - 解决: 向订阅充值 LINK

2. **回调未执行**
   - 检查合约是否添加到订阅的 Consumer 列表
   - 检查 gas limit 是否足够

3. **API 调用超时**
   - 优化 API 响应时间
   - 增加 Chainlink Functions 超时设置

4. **NFT 铸造失败**
   - 确认预言机合约有 NFT 合约的 owner 权限
   - 检查 NFT 合约的 mintCertificate 参数

## 参考资源

- [Chainlink Functions 官方文档](https://docs.chain.link/chainlink-functions)
- [Chainlink Functions 教程](https://docs.chain.link/chainlink-functions/tutorials)
- [支持的网络列表](https://docs.chain.link/chainlink-functions/supported-networks)
- [JavaScript 运行环境](https://docs.chain.link/chainlink-functions/api-reference/javascript-source)

## 联系支持

如有问题，请访问:
- [Chainlink Discord](https://discord.gg/chainlink)
- [Stack Overflow (chainlink 标签)](https://stackoverflow.com/questions/tagged/chainlink)
