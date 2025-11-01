# CourseManage 合约文档

## 合约概述

CourseManage 是一个去中心化的课程管理合约，允许讲师注册课程并让学生使用 YD 代币购买。合约采用直接转账模式，购买时代币自动分配给讲师（90%）和平台（10%），合约本身不持有资金，确保资金流转的透明和高效。

---

## 合约信息

- **合约名称**: CourseManage
- **Solidity 版本**: ^0.8.28
- **许可证**: MIT
- **依赖**: OpenZeppelin Contracts (IERC20, ReentrancyGuard)

---

## 设计理念

1. **课程 ID 由后端生成**: 使用 UUID 等唯一标识符，前端调用合约上链
2. **合约只存储核心数据**: 只存储所有权、价格等不可篡改数据
3. **直接转账模式**: 购买时代币直接转给讲师和平台，合约不持有资金
4. **分成固定**: 讲师 90%，平台 10%
5. **流程清晰**: 后端创建课程 → 前端上链 → 学生购买

---

## 核心功能

### 1. 注册课程

```solidity
function registerCourse(string calldata courseId, uint256 price) external
```

- **功能**: 将课程信息注册到区块链
- **权限**: 任何人（讲师）
- **参数**:
  - `courseId`: 后端生成的课程 ID（如 UUID）
  - `price`: 课程价格（以 YD 代币计价）
- **前置条件**:
  - 课程 ID 不能重复
  - 价格必须大于 0
- **工作流程**:
  1. 前端调用后端 API 创建课程 → 返回 courseId
  2. 前端调用此函数，将课程数据上链
- **链上存储**: 讲师地址、课程价格
- **事件**: 触发 `CourseRegistered` 事件

### 2. 购买课程

```solidity
function purchaseCourse(string calldata courseId) external nonReentrant courseExists(courseId)
```

- **功能**: 学生购买课程，代币自动分配给讲师和平台
- **权限**: 任何人（学生）
- **参数**:
  - `courseId`: 要购买的课程 ID
- **前置条件**:
  - 课程必须存在
  - 学生未购买过该课程
  - 学生不能购买自己的课程
  - 学生必须授权合约使用 YD 代币
  - 学生账户余额足够
- **分成规则**:
  - 讲师获得 90%
  - 平台获得 10%
- **工作流程**:
  1. 学生授权合约使用 YD 代币
  2. 调用此函数购买课程
  3. 代币自动转给讲师（90%）和平台（10%）
  4. 记录购买信息
- **安全保护**: 
  - 使用 ReentrancyGuard 防止重入攻击
  - 使用 CEI 模式（Checks-Effects-Interactions）
- **事件**: 触发 `CoursePurchased` 事件

### 3. 检查访问权限

```solidity
function hasAccess(address student, string memory courseId) external view courseExists(courseId) returns (bool)
```

- **功能**: 检查学生是否有权访问某课程
- **参数**:
  - `student`: 学生地址
  - `courseId`: 课程 ID
- **返回值**: 已购买返回 true，否则返回 false
- **使用场景**: 后端验证学生是否可以观看课程内容

### 4. 获取课程信息

```solidity
function getCourse(string memory courseId) external view courseExists(courseId) returns (CourseOwnership memory)
```

- **功能**: 获取课程的所有权信息
- **参数**: `courseId` - 课程 ID
- **返回值**: CourseOwnership 结构体
  - `instructor`: 讲师地址
  - `price`: 课程价格
  - `exists`: 是否存在

### 5. 获取购买记录

```solidity
function getPurchaseRecord(address student, string memory courseId) external view returns (PurchaseRecord memory)
```

- **功能**: 获取学生的购买记录
- **参数**:
  - `student`: 学生地址
  - `courseId`: 课程 ID
- **返回值**: PurchaseRecord 结构体
  - `timestamp`: 购买时间戳
  - `paidPrice`: 实际支付价格
  - `purchased`: 是否已购买

### 6. 更新平台地址

```solidity
function updatePlatformAddress(address newAddress) external onlyPlatform
```

- **功能**: 更新平台收款地址
- **权限**: 仅当前平台地址
- **参数**: `newAddress` - 新的平台地址
- **前置条件**: 新地址不能为零地址

---

## 数据结构

### CourseOwnership 结构体

```solidity
struct CourseOwnership {
    address instructor;  // 讲师地址
    uint256 price;       // 课程价格
    bool exists;         // 是否存在
}
```

**说明**: 存储课程的核心所有权信息，这些数据一旦上链不可修改

### PurchaseRecord 结构体

```solidity
struct PurchaseRecord {
    uint256 timestamp;   // 购买时间
    uint256 paidPrice;   // 实际支付价格
    bool purchased;      // 是否已购买
}
```

**说明**: 记录学生的购买信息，用于访问权限验证和历史记录

---

## 状态变量

| 变量名 | 类型 | 可见性 | 说明 |
|--------|------|--------|------|
| `ydToken` | IERC20 | public immutable | YD 代币合约接口（不可变） |
| `platformAddress` | address | public | 平台收款地址 |
| `INSTRUCTOR_RATE` | uint256 | public constant | 讲师分成比例 90% |
| `PLATFORM_RATE` | uint256 | public constant | 平台分成比例 10% |
| `courses` | mapping(string => CourseOwnership) | public | 课程 ID 到课程所有权的映射 |
| `purchases` | mapping(address => mapping(string => PurchaseRecord)) | public | 学生地址 → 课程 ID → 购买记录 |

---

## 事件

### CourseRegistered

```solidity
event CourseRegistered(
    string indexed courseId,
    address indexed instructor,
    uint256 price,
    uint256 timestamp
)
```

- **触发时机**: 课程注册成功时
- **参数**:
  - `courseId`: 课程 ID（索引）
  - `instructor`: 讲师地址（索引）
  - `price`: 课程价格
  - `timestamp`: 注册时间戳

### CoursePurchased

```solidity
event CoursePurchased(
    string indexed courseId,
    address indexed student,
    address indexed instructor,
    uint256 price,
    uint256 timestamp
)
```

- **触发时机**: 学生购买课程成功时
- **参数**:
  - `courseId`: 课程 ID（索引）
  - `student`: 学生地址（索引）
  - `instructor`: 讲师地址（索引）
  - `price`: 支付价格
  - `timestamp`: 购买时间戳

---

## 错误定义

| 错误名称 | 说明 |
|---------|------|
| `InvalidAddress` | 无效的地址（零地址） |
| `InvalidPrice` | 无效的价格（价格为 0） |
| `CourseAlreadyExists` | 课程已存在 |
| `CourseNotExist` | 课程不存在 |
| `AlreadyPurchased` | 已经购买过该课程 |
| `InsufficientBalance` | 余额不足 |
| `OnlyPlatform` | 只有平台可以调用 |

---

## 权限控制

| 功能 | 权限要求 |
|------|----------|
| 注册课程 | 任何人（讲师） |
| 购买课程 | 任何人（学生） |
| 检查访问权限 | 任何人（view 函数） |
| 获取课程信息 | 任何人（view 函数） |
| 获取购买记录 | 任何人（view 函数） |
| 更新平台地址 | 仅当前平台地址 |

---

## 使用流程

### 完整业务流程

```
1. 讲师在后端创建课程
   ↓
2. 后端返回 courseId (UUID)
   ↓
3. 前端调用 registerCourse() 上链
   ↓
4. 学生授权合约使用 YD 代币
   ↓
5. 学生调用 purchaseCourse() 购买
   ↓
6. 代币自动分配：讲师 90%，平台 10%
   ↓
7. 后端通过 hasAccess() 验证访问权限
   ↓
8. 学生观看课程内容
```

### 讲师注册课程示例

```solidity
// 1. 后端生成课程 ID
string courseId = "course-uuid-12345";

// 2. 前端调用合约注册课程
uint256 price = 100 * 10**18; // 100 YD
courseManage.registerCourse(courseId, price);
```

### 学生购买课程示例

```solidity
// 1. 学生授权合约使用代币
ydToken.approve(courseManageAddress, coursePrice);

// 2. 购买课程
courseManage.purchaseCourse("course-uuid-12345");

// 购买后，讲师自动收到 90 YD，平台收到 10 YD
```

### 后端验证访问权限示例

```solidity
// 检查学生是否有权限访问课程
bool canAccess = courseManage.hasAccess(studentAddress, "course-uuid-12345");

if (canAccess) {
    // 允许观看课程
} else {
    // 提示需要购买
}
```

---

## 分成机制详解

### 分成比例

- **讲师**: 90%（固定，常量定义）
- **平台**: 10%（固定，常量定义）

### 计算公式

```solidity
uint256 instructorAmount = (coursePrice * 90) / 100;
uint256 platformAmount = coursePrice - instructorAmount;
```

### 转账流程

```
学生账户
   ↓ (100% 课程价格)
   ├─→ 讲师账户 (90%)
   └─→ 平台账户 (10%)
```

**特点**:
- 合约不持有任何资金
- 转账在一个交易中完成
- 原子性操作，要么全部成功，要么全部失败

### 分成示例

假设课程价格为 100 YD：
- 讲师收到：90 YD
- 平台收到：10 YD
- 合约余额：0 YD

---

## 安全特性

1. **重入攻击防护**: 使用 OpenZeppelin 的 ReentrancyGuard
2. **CEI 模式**: 
   - Checks（检查）：验证所有前置条件
   - Effects（效果）：更新状态变量
   - Interactions（交互）：与外部合约交互
3. **权限控制**: 
   - 使用 `onlyPlatform` 修饰符保护管理功能
   - 防止学生购买自己的课程
4. **输入验证**: 
   - 检查地址有效性
   - 检查价格有效性
   - 检查课程存在性
5. **状态管理**: 
   - 防止重复购买
   - 防止重复注册
6. **immutable 变量**: ydToken 不可变，部署后无法更改
7. **事件记录**: 所有关键操作都触发事件，便于追踪和审计

---

## Gas 优化

### 已实现的优化

1. **使用 calldata**: 函数参数使用 `calldata` 而非 `memory`
2. **immutable 变量**: ydToken 使用 `immutable` 减少存储读取
3. **constant 常量**: 分成比例使用 `constant`
4. **短路计算**: 分成计算使用减法而非再次乘除
5. **自定义错误**: 使用自定义 error 而非 string revert

### Gas 消耗估算

| 操作 | 预估 Gas |
|------|----------|
| 注册课程 | ~80,000 |
| 购买课程 | ~120,000 |
| 查询访问权限 | ~3,000 (view) |
| 查询课程信息 | ~3,000 (view) |

---

## 与后端集成

### 推荐架构

```
前端 ←→ 后端 API ←→ 数据库
  ↓                      ↑
区块链 ←────────────────┘
```

### 数据存储策略

| 数据类型 | 存储位置 | 原因 |
|---------|---------|------|
| 课程 ID | 后端生成 | UUID 生成，保证唯一性 |
| 课程标题、描述 | 数据库 | 可变内容，降低链上成本 |
| 讲师地址、价格 | 区块链 | 不可篡改，保证公平 |
| 购买记录 | 区块链 | 访问权限验证 |
| 课程内容、视频 | IPFS/服务器 | 大文件，不适合上链 |

### API 接口建议

```javascript
// 1. 创建课程
POST /api/courses
{
  title: "课程标题",
  description: "课程描述",
  instructorAddress: "0x...",
  price: "100000000000000000000" // 100 YD
}
// 返回: { courseId: "uuid-xxx" }

// 2. 上链（前端调用）
courseManage.registerCourse(courseId, price)

// 3. 验证访问权限（后端调用）
GET /api/courses/{courseId}/access?student=0x...
// 后端调用合约 hasAccess() 验证
```

---

## 前端集成示例

### Web3.js 示例

```javascript
// 1. 连接钱包
const web3 = new Web3(window.ethereum);
await window.ethereum.request({ method: 'eth_requestAccounts' });

// 2. 实例化合约
const courseManage = new web3.eth.Contract(ABI, contractAddress);

// 3. 注册课程
const courseId = "course-uuid-12345";
const price = web3.utils.toWei("100", "ether"); // 100 YD

await courseManage.methods
  .registerCourse(courseId, price)
  .send({ from: instructorAddress });

// 4. 购买课程
// 先授权
const ydToken = new web3.eth.Contract(ERC20_ABI, tokenAddress);
await ydToken.methods
  .approve(contractAddress, price)
  .send({ from: studentAddress });

// 再购买
await courseManage.methods
  .purchaseCourse(courseId)
  .send({ from: studentAddress });

// 5. 检查访问权限
const hasAccess = await courseManage.methods
  .hasAccess(studentAddress, courseId)
  .call();
```

### Ethers.js 示例

```javascript
// 1. 连接钱包
const provider = new ethers.providers.Web3Provider(window.ethereum);
await provider.send("eth_requestAccounts", []);
const signer = provider.getSigner();

// 2. 实例化合约
const courseManage = new ethers.Contract(contractAddress, ABI, signer);

// 3. 注册课程
const tx = await courseManage.registerCourse(
  courseId,
  ethers.utils.parseEther("100")
);
await tx.wait();

// 4. 购买课程
const ydToken = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
await ydToken.approve(contractAddress, price);
await courseManage.purchaseCourse(courseId);

// 5. 监听事件
courseManage.on("CoursePurchased", (courseId, student, instructor, price, timestamp) => {
  console.log(`课程 ${courseId} 已被 ${student} 购买`);
});
```

---

## 注意事项

⚠️ **重要提示**:

1. **课程 ID 管理**:
   - 必须由后端生成唯一 ID（推荐使用 UUID）
   - 课程 ID 一旦上链不可修改
   - 建议在后端做好 ID 重复检查

2. **授权流程**:
   - 学生购买前必须先授权合约使用 YD 代币
   - 建议前端做好授权状态检测和提示

3. **价格设置**:
   - 价格必须大于 0
   - 注意代币精度（通常是 18 位小数）
   - 价格一旦设置不可修改

4. **资金流转**:
   - 合约不持有任何资金
   - 代币直接从学生转给讲师和平台
   - 转账失败会回滚整个交易

5. **分成比例**:
   - 分成比例固定为常量，不可动态调整
   - 如需修改需重新部署合约

6. **课程内容**:
   - 合约只存储所有权信息
   - 课程内容应存储在链下（数据库/IPFS）
   - 通过 hasAccess() 验证访问权限

7. **Gas 费用**:
   - 注册课程和购买课程都需要消耗 Gas
   - 建议在测试网充分测试

8. **平台地址**:
   - 平台地址可以更新，但只能由当前平台地址操作
   - 务必妥善保管平台私钥

9. **安全审计**:
   - 建议在主网部署前进行完整的安全审计
   - 特别关注资金转账逻辑

---

## 示例场景

### 场景 1: 讲师发布新课程

```solidity
// 1. 后端创建课程记录
POST /api/courses
{
  "title": "Solidity 入门教程",
  "description": "从零开始学习 Solidity",
  "instructor": "0x1234...5678"
}
// 返回: courseId = "550e8400-e29b-41d4-a716-446655440000"

// 2. 前端调用合约上链
courseManage.registerCourse(
  "550e8400-e29b-41d4-a716-446655440000",
  ethers.utils.parseEther("50") // 50 YD
);

// 3. 课程上线，学生可以购买
```

### 场景 2: 学生购买课程

```solidity
// 1. 学生浏览课程，点击购买
courseId = "550e8400-e29b-41d4-a716-446655440000";
price = 50 YD;

// 2. 检查是否已购买
bool purchased = await courseManage.hasAccess(studentAddress, courseId);
if (purchased) {
  alert("您已购买此课程");
  return;
}

// 3. 检查余额
uint256 balance = await ydToken.balanceOf(studentAddress);
if (balance < price) {
  alert("余额不足");
  return;
}

// 4. 授权合约
await ydToken.approve(contractAddress, price);

// 5. 购买课程
await courseManage.purchaseCourse(courseId);

// 6. 购买成功，跳转到课程内容页面
```

### 场景 3: 后端验证访问权限

```javascript
// 学生请求观看课程视频
app.get('/api/courses/:courseId/video', async (req, res) => {
  const { courseId } = req.params;
  const studentAddress = req.user.walletAddress;
  
  // 调用合约检查访问权限
  const hasAccess = await courseManage.methods
    .hasAccess(studentAddress, courseId)
    .call();
  
  if (!hasAccess) {
    return res.status(403).json({ error: "请先购买课程" });
  }
  
  // 返回视频链接
  const videoUrl = await getVideoUrl(courseId);
  res.json({ videoUrl });
});
```

---

## 升级和维护

### 可升级性考虑

当前合约不支持升级，如需升级功能，建议：

1. **代理模式**: 使用 OpenZeppelin 的 UUPS 或 Transparent Proxy
2. **新版本部署**: 部署新合约，迁移数据
3. **功能扩展**: 通过新合约调用旧合约数据

### 常见维护场景

| 场景 | 解决方案 |
|------|----------|
| 修改分成比例 | 部署新合约 |
| 添加新功能 | 部署新版本合约 |
| 修复 bug | 部署新合约，暂停旧合约使用 |
| 更换平台地址 | 调用 updatePlatformAddress() |

---

## 合约地址

- **网络**: [待部署]
- **合约地址**: [待部署]
- **YD 代币地址**: [待配置]
- **平台地址**: [待配置]

---

## 版本历史

- **v1.0**: 初始版本
  - 课程注册功能
  - 课程购买功能
  - 自动分成机制（讲师 90%，平台 10%）
  - 访问权限验证
  - 平台地址管理

---

## 常见问题 (FAQ)

### Q1: 为什么合约不存储课程标题和描述？

A: 为了节省 Gas 费用和降低链上存储成本。标题、描述等可变内容存储在链下数据库，合约只存储不可篡改的核心数据（所有权、价格）。

### Q2: 课程价格可以修改吗？

A: 不可以。课程价格一旦上链就不可修改。如需调整价格，需要重新注册新的课程。

### Q3: 讲师可以修改分成比例吗？

A: 不可以。分成比例是合约常量（讲师 90%，平台 10%），所有课程统一适用，不支持单独设置。

### Q4: 如果转账失败会怎样？

A: 整个交易会回滚，学生不会被扣款，购买记录也不会保存。这是区块链交易的原子性保证。

### Q5: 学生可以退款吗？

A: 当前合约不支持退款功能。代币一旦转出就无法撤回。如需退款功能，需要在合约中添加相应逻辑。

### Q6: 合约如何防止重复购买？

A: 通过 `purchases` 映射记录购买状态，购买前检查 `purchased` 字段。如果已购买，交易会回滚。

### Q7: 讲师可以购买自己的课程吗？

A: 不可以。合约会检查 `msg.sender` 是否为讲师，如果是则拒绝交易。

### Q8: 平台地址丢失怎么办？

A: 平台地址可以通过 `updatePlatformAddress()` 更新，但只能由当前平台地址操作。如果私钥丢失，需要社区治理或重新部署合约。

### Q9: 如何处理课程下架？

A: 合约不提供下架功能。建议在后端标记课程状态，前端不展示已下架课程。已购买的学生仍可访问。

### Q10: 支持多种代币支付吗？

A: 不支持。合约只接受 YD 代币支付。如需支持其他代币，需要部署多个合约实例。

---

## 相关链接

- **OpenZeppelin 文档**: https://docs.openzeppelin.com/contracts/
- **Solidity 文档**: https://docs.soliditylang.org/
- **Web3.js 文档**: https://web3js.readthedocs.io/
- **Ethers.js 文档**: https://docs.ethers.io/

---

## 技术支持

如有问题或建议，请联系：
- **GitHub Issues**: [项目仓库]
- **Discord**: [社区链接]
- **Email**: [联系邮箱]