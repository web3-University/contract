# Chainlink Functions 工作机制详解

## 核心概念

Chainlink Functions 是一个**去中心化的无服务器计算平台**，允许智能合约执行链下代码（JavaScript）并获取可信的结果。

### ⚠️ 常见误解

很多人认为流程是这样的（❌ 错误）：
```
后端服务器 → 调用 Chainlink API → 链上回调
```

### ✅ 实际流程

正确的流程是：
```
链上合约 → Chainlink DON 执行 JS → 调用你的 API → 链上回调
```

## 详细工作流程

### 步骤 1：链上请求（在区块链上）

```solidity
// CourseNFTOracle.sol
function requestCourseCompletion(address student, uint256 courseId, ...) {
    // 1. 准备 JavaScript 源代码
    string memory jsCode = source; // 从合约存储中读取

    // 2. 创建请求
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);

    // 3. 设置参数（会传给 JS）
    string[] memory args = new string[](2);
    args[0] = addressToString(student);   // "0x742d35..."
    args[1] = uint256ToString(courseId);  // "101"
    req.setArgs(args);

    // 4. 发送到 Chainlink Router
    bytes32 requestId = _sendRequest(
        req.encodeCBOR(),      // 包含: JS 代码 + 参数
        subscriptionId,        // 你的订阅 ID
        gasLimit,              // 回调 gas 限制
        donId                  // 预言机网络 ID
    );

    // 5. 记录请求
    requests[requestId] = CourseCompletionRequest({...});

    emit RequestSent(requestId, student, courseId, courseName);
}
```

**此时发生了什么？**
- ✅ 交易上链
- ✅ Chainlink Router 接收到请求
- ✅ 请求包含：JS 代码、参数、回调配置
- ✅ 支付 LINK 代币

### 步骤 2：DON 执行 JavaScript（链下）

Chainlink DON（去中心化预言机网络）由多个独立节点组成：

```javascript
// 这段代码在 Chainlink 节点的 JavaScript 运行时中执行
// 不是在你的服务器上，也不是在区块链上

// ① 接收参数（从链上传来）
const studentAddress = args[0];  // "0x742d35..."
const courseId = args[1];        // "101"

// ② 调用你的后端 API
const apiUrl = `https://api.web3university.com/courses/${courseId}/students/${studentAddress}/completion`;

const response = await Functions.makeHttpRequest({
  url: apiUrl,
  method: "GET",
  headers: {
    "Content-Type": "application/json"
  },
  timeout: 9000
});

// ③ 处理响应
if (response.error) {
  throw Error("API request failed");
}

const data = response.data;

// ④ 返回结果（会被发回链上）
if (data.completed === true) {
  return Functions.encodeUint256(1);  // 已完成
} else {
  return Functions.encodeUint256(0);  // 未完成
}
```

**在哪里执行？**
- ❌ 不是在你的后端服务器
- ❌ 不是在区块链上
- ✅ 在 Chainlink DON 的多个节点上（去中心化执行）

**节点行为：**
```
Node 1 执行 JS → 调用你的 API → 得到结果 1
Node 2 执行 JS → 调用你的 API → 得到结果 1
Node 3 执行 JS → 调用你的 API → 得到结果 1
                  ↓
           节点之间达成共识
                  ↓
         确认最终结果 = 1
```

### 步骤 3：链上回调（在区块链上）

```solidity
// CourseNFTOracle.sol
function fulfillRequest(
    bytes32 requestId,
    bytes memory response,  // ← Chainlink 传回的结果
    bytes memory err
) internal override {
    // ① 验证请求
    CourseCompletionRequest storage request = requests[requestId];
    require(request.student != address(0), "Unknown request");

    // ② 标记已完成
    request.fulfilled = true;

    // ③ 检查错误
    if (err.length > 0) {
        request.success = false;
        emit RequestFulfilled(requestId, student, courseId, false, 0);
        return;
    }

    // ④ 解码结果
    uint256 completionStatus = abi.decode(response, (uint256));

    // ⑤ 如果验证通过，铸造 NFT
    if (completionStatus == 1) {
        uint256 tokenId = nftContract.mintCertificate(
            request.student,
            request.courseId,
            request.courseName,
            block.timestamp
        );

        request.success = true;
        emit RequestFulfilled(requestId, student, courseId, true, tokenId);
    }
}
```

## 为什么 JS 代码在合约里？

### 原因 1：去中心化和透明性

```solidity
// JS 代码存储在区块链上 → 任何人都可以验证
string public source = "const response = await Functions.makeHttpRequest({...})";

// ✅ 优点：
// - 完全透明，任何人都能看到执行逻辑
// - 去中心化，不依赖中心化服务器
// - 可验证，每个人都能审计代码
```

### 原因 2：动态更新

```solidity
// 管理员可以更新验证逻辑，无需重新部署合约
function updateSource(string calldata newSource) external onlyOwner {
    source = newSource;
    emit SourceCodeUpdated(newSource);
}

// 示例：更新 API URL
await oracle.updateSource(`
    const response = await Functions.makeHttpRequest({
        url: 'https://new-api.com/verify',
        method: 'POST',
        data: { student: args[0], course: args[1] }
    });
    return Functions.encodeUint256(response.data.verified ? 1 : 0);
`);
```

### 原因 3：链上触发

```solidity
// 每次请求时，JS 代码会被编码到交易中
function requestCourseCompletion(...) {
    // 将 JS 代码打包进请求
    req.initializeRequestForInlineJavaScript(source);

    // 发送到 Chainlink
    _sendRequest(req.encodeCBOR(), ...);
}
```

## 三种方式对比

### 方式 1：Inline JavaScript（当前使用）

```solidity
string public source = "...JS code here...";

req.initializeRequestForInlineJavaScript(source);
```

| 特性 | 说明 |
|------|------|
| 存储位置 | 合约存储 |
| Gas 成本 | 高（代码长度 × gas） |
| 灵活性 | 高（可随时更新） |
| 适用场景 | 代码较短，需要频繁更新 |

### 方式 2：Remote JavaScript

```solidity
string url = "https://raw.githubusercontent.com/user/repo/main/source.js";

req.initializeRequestForRemoteCode(url);
```

| 特性 | 说明 |
|------|------|
| 存储位置 | GitHub/IPFS |
| Gas 成本 | 低（只存 URL） |
| 灵活性 | 中（需要更新远程文件） |
| 适用场景 | 代码较长，不常更新 |

### 方式 3：DON-Hosted JavaScript

```solidity
bytes32 codeHash = 0x1234...abcd;

req.initializeRequestForDONHostedCode(codeHash);
```

| 特性 | 说明 |
|------|------|
| 存储位置 | Chainlink DON |
| Gas 成本 | 最低（只存哈希） |
| 灵活性 | 低（需要预先上传） |
| 适用场景 | 生产环境，代码稳定 |

## 完整流程图

```
┌─────────────────────────────────────────────────────────────────────┐
│                          时间线视角                                   │
└─────────────────────────────────────────────────────────────────────┘

时刻 T0: 用户/管理员发起请求
        │
        │ tx: oracle.requestCourseCompletion(student, courseId, ...)
        ▼
    ┌─────────────────────────────────────────┐
    │   链上：CourseNFTOracle 合约             │
    │   - 读取 JS 源代码（source）             │
    │   - 编码请求（代码+参数）                 │
    │   - 发送到 Chainlink Router             │
    │   - 记录请求状态                         │
    │   - 消耗 LINK                           │
    └─────────────────────────────────────────┘
        │
        │ 交易上链，RequestSent 事件触发
        ▼

时刻 T1: Chainlink DON 接收请求（~几秒后）
        │
        ▼
    ┌─────────────────────────────────────────┐
    │   链下：Chainlink DON                    │
    │                                         │
    │   Node 1      Node 2      Node 3        │
    │     ↓           ↓           ↓           │
    │   执行 JS     执行 JS     执行 JS        │
    │     ↓           ↓           ↓           │
    │   HTTP        HTTP        HTTP          │
    │   请求        请求        请求            │
    └─────────────────────────────────────────┘
        │              │             │
        │              │             │
        ▼              ▼             ▼

时刻 T2: 调用后端 API（并行）
    ┌─────────────────────────────────────────┐
    │   你的后端 API 服务器                     │
    │                                         │
    │   GET /courses/101/students/0x.../      │
    │       completion                        │
    │                                         │
    │   返回: { completed: true, ... }        │
    └─────────────────────────────────────────┘
        │              │             │
        │              │             │
        ▼              ▼             ▼

时刻 T3: DON 节点处理结果并达成共识（~10-30秒）
    ┌─────────────────────────────────────────┐
    │   Chainlink DON 共识机制                 │
    │                                         │
    │   Node 1 结果: 1                        │
    │   Node 2 结果: 1                        │
    │   Node 3 结果: 1                        │
    │                                         │
    │   共识结果: 1 (已完成)                   │
    └─────────────────────────────────────────┘
        │
        │ 准备回调交易
        ▼

时刻 T4: 回调到链上（自动触发）
        │
        │ tx: oracle.fulfillRequest(requestId, response, err)
        ▼
    ┌─────────────────────────────────────────┐
    │   链上：CourseNFTOracle 合约             │
    │   - 解码结果                             │
    │   - completionStatus = 1                │
    │   - 调用 NFT 合约铸造                    │
    │   - 更新请求状态                         │
    │   - 触发 RequestFulfilled 事件          │
    └─────────────────────────────────────────┘
        │
        ▼

时刻 T5: NFT 铸造成功
    ┌─────────────────────────────────────────┐
    │   链上：SimpleYDNFT 合约                 │
    │   - mint NFT #1234                      │
    │   - 转账给学生                           │
    │   - 触发 NFTMinted 事件                 │
    └─────────────────────────────────────────┘

总耗时：通常 30-60 秒
```

## 数据流向

```
┌───────────────┐
│   合约存储     │  ← JS 源代码存储在这里
└───────────────┘
        │
        │ (1) 读取 source
        ▼
┌───────────────┐
│ 请求交易       │  ← 包含：JS 代码 + args + 配置
└───────────────┘
        │
        │ (2) 上链
        ▼
┌───────────────┐
│ Chainlink     │  ← Router 接收请求
│   Router      │
└───────────────┘
        │
        │ (3) 路由到 DON
        ▼
┌───────────────┐
│ DON Node 1    │─┐
│ DON Node 2    │─┼─ (4) 并行执行 JS
│ DON Node 3    │─┘
└───────────────┘
        │
        │ (5) HTTP 请求
        ▼
┌───────────────┐
│ 你的 API      │  ← 返回课程完成状态
└───────────────┘
        │
        │ (6) 响应
        ▼
┌───────────────┐
│ DON 共识      │  ← 节点达成一致
└───────────────┘
        │
        │ (7) 回调交易
        ▼
┌───────────────┐
│ fulfillRequest│  ← 结果返回合约
└───────────────┘
        │
        │ (8) 铸造 NFT
        ▼
┌───────────────┐
│ NFT 合约      │
└───────────────┘
```

## 关键点总结

### ✅ JavaScript 代码的作用

1. **存储在合约中**：透明、可验证、可更新
2. **随请求发送**：每次请求都携带代码
3. **在 DON 执行**：去中心化执行，不依赖你的服务器
4. **调用你的 API**：通过 HTTP 请求获取数据
5. **结果返回链上**：通过回调触发后续逻辑

### ✅ 你的后端 API 的作用

- **被动响应**：只是被 Chainlink 节点调用
- **提供数据**：返回学生的课程完成状态
- **无需链上交互**：不需要调用合约，不需要私钥
- **标准 REST API**：就是普通的 HTTP 接口

### ✅ Chainlink DON 的作用

- **执行 JavaScript**：在安全的沙箱环境中
- **调用外部 API**：代替智能合约访问链下数据
- **达成共识**：多个节点验证结果一致性
- **链上回调**：将结果可信地写回区块链

## 为什么不直接让后端调用合约？

### 方案 A：后端直接调用（❌ 不推荐）

```javascript
// 你的后端
app.post('/mint-nft', async (req, res) => {
    // 需要私钥 ← 安全风险！
    const wallet = new ethers.Wallet(PRIVATE_KEY);

    // 调用合约
    await nftContract.mintCertificate(...);
});
```

**问题**：
- ❌ 后端需要保管私钥（安全风险）
- ❌ 中心化（单点故障）
- ❌ 不透明（用户无法验证逻辑）
- ❌ 需要支付 gas

### 方案 B：Chainlink Functions（✅ 推荐）

```solidity
// 智能合约
function requestCourseCompletion(...) {
    // 不需要私钥
    // 去中心化执行
    // 完全透明
    _sendRequest(...);
}
```

**优点**：
- ✅ 去中心化（多节点执行）
- ✅ 透明（代码在链上）
- ✅ 安全（无需后端私钥）
- ✅ 可验证（任何人都能审计）

## 实际案例

### 场景：学生完成课程

```
1. 学生在前端点击"申请证书"
   ↓
2. 前端调用合约：oracle.requestCourseCompletion(studentAddr, 101, "区块链基础")
   ↓
3. 合约发送请求到 Chainlink，包含 JS 代码和参数
   ↓
4. Chainlink 的多个节点同时执行 JS
   ↓
5. JS 调用你的 API：GET /courses/101/students/0x.../completion
   ↓
6. 你的 API 返回：{ completed: true }
   ↓
7. 节点达成共识：结果 = 1
   ↓
8. Chainlink 回调合约：fulfillRequest(requestId, 1, "")
   ↓
9. 合约自动铸造 NFT 给学生
   ↓
10. 学生收到 NFT 证书 🎉
```

### 你的后端只需要：

```javascript
// 简单的 REST API
app.get('/courses/:courseId/students/:address/completion', (req, res) => {
    const student = db.findStudent(req.params.address, req.params.courseId);

    res.json({
        completed: student ? student.completed : false
    });
});
```

**不需要**：
- ❌ 调用区块链
- ❌ 管理私钥
- ❌ 支付 gas
- ❌ 铸造 NFT

全部由 Chainlink Functions 和智能合约自动处理！

---

希望这个文档彻底解释清楚了！🎯
