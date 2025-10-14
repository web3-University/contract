# Web3 大学课程合约系统

一个基于以太坊智能合约的去中心化课程交易平台，支持课程创建、购买、进度追踪、退款和讲师提现等完整功能。

## 项目简介

本项目采用模块化架构设计，实现了一个完整的链上课程管理和支付系统。主要特性包括：

- **课程管理**：认证讲师创建、发布、更新和删除课程
- **支付分账**：智能合约自动分账，讲师获得90%，平台获得10%
- **学习进度追踪**：链上记录学生学习进度
- **退款机制**：7天退款窗口，进度低于30%可申请70%退款
- **讲师提现**：讲师可随时提取已赚取的收益
- **质押挖矿**：YD代币支持质押获取收益（30/90/180天锁定期）
- **讲师认证**：平台管理员可认证和管理讲师
- **紧急控制**：支持合约暂停和紧急提款

## 技术架构

### 核心合约

#### 1. CourseContract.sol
主合约，整合所有功能模块：
- 继承 `RefundModule`、`WithdrawalModule`、`ReentrancyGuard`、`Pausable`
- 管理课程生命周期
- 处理支付和分账逻辑
- 提供完整的查询接口

#### 2. SimpleYDToken.sol
平台代币合约，支持：
- ERC20 标准实现
- ETH 兑换 YD（汇率 1:4000）
- 质押挖矿功能（APY: 5%-20%）
- 批量转账功能

### 模块化架构

#### Libraries（库文件）
- `CourseManagement.sol` - 课程创建和管理逻辑
- `PaymentDistributor.sol` - 支付分账逻辑
- `ProgressTracker.sol` - 学习进度追踪
- `PurchaseLogic.sol` - 购买流程和收益计算
- `RefundLogic.sol` - 退款资格验证
- `WithdrawalLogic.sol` - 提现逻辑

#### Modules（功能模块）
- `PurchaseModule.sol` - 购买相关数据结构
- `QueryModule.sol` - 批量查询功能
- `RefundModule.sol` - 退款请求管理
- `WithdrawalModule.sol` - 讲师提现管理

#### Interfaces（接口定义）
- `ICourseContract.sol` - 课程合约接口
- `IEconomicModel.sol` - 经济模型数据结构
- `IERC20.sol` - ERC20 标准接口

## 部署指南

### 环境要求

- Node.js >= 16.x
- Hardhat 3.x
- TypeScript 5.x

### 安装依赖

```bash
npm install
# 或
yarn install
```

### 本地部署步骤

1. **启动本地 Hardhat 节点**
```bash
npx hardhat node
```

2. **部署 YD 代币合约**（新终端）
```bash
npx hardhat ignition deploy --network localhost ignition/modules/SimpleYDToken.ts
```

3. **部署课程合约**
```bash
npx hardhat ignition deploy --network localhost ignition/modules/CourseContract.ts
```

部署完成后，合约会自动创建4个示例课程：
- Solidity从入门到精通（100 YD）
- Web3前端开发入门（400 YD）
- NFT市场开发实战（300 YD）
- DeFi协议开发实战（200 YD）

### Sepolia 测试网部署

1. **配置环境变量**

创建 Hardhat 变量（推荐使用 Hardhat Vars）：
```bash
npx hardhat vars set SEPOLIA_RPC_URL
npx hardhat vars set SEPOLIA_PRIVATE_KEY
npx hardhat vars set ETHERSCAN_API_KEY
```

2. **修改部署配置**

编辑 [ignition/modules/CourseContract.ts](ignition/modules/CourseContract.ts)：
```typescript
// 修改第5-6行
// const chainId = 31337;
const chainId = 11155111;

// 修改第29行，填入讲师地址
11155111: "0xYourInstructorAddress",
```

3. **部署到 Sepolia**
```bash
npx hardhat ignition deploy --network sepolia ignition/modules/SimpleYDToken.ts
npx hardhat ignition deploy --network sepolia ignition/modules/CourseContract.ts
```

4. **验证合约**（可选）
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 核心功能说明

### 1. 讲师认证系统

只有认证讲师才能创建课程。平台管理员可以：

```solidity
// 认证单个讲师
certifyInstructor(address instructor)

// 批量认证讲师（最多100个）
batchCertifyInstructors(address[] calldata instructors)

// 撤销讲师认证
revokeInstructor(address instructor)

// 查询认证状态
isCertifiedInstructor(address instructor) → bool
```

### 2. 课程管理

**创建课程**（仅认证讲师）
```solidity
createCourse(
    string memory title,        // 课程标题
    address instructor,         // 讲师地址（必须是msg.sender）
    uint256 price,             // 价格（YD代币）
    uint256 totalLessons       // 总课时数
) → uint256 courseId
```

**更新课程信息**
```solidity
updateCourse(uint256 courseId, string memory title, uint96 totalLessons)
updateCoursePrice(uint256 courseId, uint256 newPrice)
```

**发布/下架课程**
```solidity
publishCourse(uint256 courseId)      // 发布课程
unpublishCourse(uint256 courseId)    // 取消发布
```

**删除课程**
```solidity
deleteCourse(uint256 courseId)       // 仅当无学生购买时可删除
```

### 3. 购买课程

学生购买课程时会自动：
- 扣除学生账户 YD 代币
- 平台收取 10%
- 讲师收益 90% 计入待提现余额
- 初始化学习进度
- 记录购买时间戳

```solidity
purchaseCourse(uint256 courseId)
```

查询访问权限：
```solidity
hasAccess(address student, uint256 courseId) → bool
batchCheckAccess(address student, uint256[] memory courseIds) → bool[]
```

### 4. 学习进度追踪

```solidity
// 更新进度
updateProgress(uint256 courseId, uint256 completedLessons)

// 查询进度
getProgress(address student, uint256 courseId) → LearningProgress {
    uint256 totalLessons;
    uint256 completedLessons;
    uint256 progressPercent;
    uint256 lastUpdated;
}
```

### 5. 退款机制

**退款条件**：
- 购买后 1-7 天内
- 学习进度 ≤ 30%
- 未曾退款过该课程

**退款金额**：原价的 70%

```solidity
// 申请退款（自动审批）
requestRefund(uint256 courseId) → uint256 requestId

// 检查退款资格
canRefund(address student, uint256 courseId) → (bool canRefundNow, string memory reason)

// 详细退款信息
getRefundEligibilityDetails(address student, uint256 courseId) → (
    bool eligible,
    string memory reason,
    uint256 refundAmount,
    uint256 daysRemaining,
    uint256 progressPercent,
    uint256 timeUntilEligible
)
```

### 6. 讲师提现

讲师可随时提取已赚取的收益：

```solidity
// 提现
withdrawEarnings() → uint256 amount

// 查询收益
getInstructorEarnings(address instructor) → InstructorEarnings {
    uint256 pending;      // 待提现金额
    uint256 withdrawn;    // 已提现总额
    uint256 refunded;     // 退款扣除总额
}
```

**提现限制**：
- 最小提现金额：10 YD
- 提现冷却期：1 天

### 7. YD 代币质押挖矿

**质押套餐**：

| 锁定期 | 年化收益率 (APY) |
|--------|------------------|
| 30天   | 5%               |
| 90天   | 10%              |
| 180天  | 20%              |

**质押操作**：
```solidity
// 质押
stake(uint256 amount, uint256 lockPeriod)  // lockPeriod: 30/90/180天

// 解除质押
unstake(bool forceUnlock)  // 提前解锁扣除20%本金

// 领取收益（不解除质押）
claimReward()

// 查询质押信息
getStakeInfo(address user) → StakeInfo
calculatePendingReward(address user) → uint256
canUnstake(address user) → bool
```

### 8. 平台管理

**费率配置**（仅平台管理员）
```solidity
updateFeeConfig(FeeConfig memory newConfig)  // 讲师率 + 平台率必须 = 100
updateRefundWindow(uint256 newWindow)        // 调整退款窗口
updatePlatformAddress(address newPlatform)   // 更新平台地址
```

**紧急控制**
```solidity
pause()      // 暂停合约（禁止购买、退款、提现）
unpause()    // 恢复运行
emergencyWithdraw(address token, address to, uint256 amount)  // 紧急提款
```

**平台统计**
```solidity
getPlatformStats() → (
    uint256 totalCourses,
    uint256 totalInstructors,
    uint256 totalRefunds,
    uint256 totalEnrollments,
    uint256 totalRevenue,
    uint256 activeInstructors
)

getInstructorStats(address instructor) → (
    uint256 coursesCreated,
    uint256 totalStudents,
    InstructorEarnings memory earnings
)

getCourseStats(uint256 courseId) → (
    Course memory course,
    uint256 studentsCount,
    uint256 totalEarnings,
    uint256 refundsCount
)
```

### 9. 合约健康检查

```solidity
getContractHealth() → (
    uint256 contractBalance,   // 合约YD余额
    uint256 totalPending,      // 所有讲师待提现总额
    bool isHealthy             // 余额 >= 待提现为健康
)

getInstructorList() → address[]  // 所有有收益的讲师列表
```

## 查询接口

```solidity
// 课程查询
getCourse(uint256 courseId) → Course
getTotalCourses() → uint256
getCourseStudents(uint256 courseId) → address[]
getCourseStudentCount(uint256 courseId) → uint256
getInstructorCourses(address instructor) → uint256[]

// 学生查询
getStudentCourses(address student) → uint256[]
getPurchaseTimestamp(address student, uint256 courseId) → uint256

// 配置查询
getFeeConfig() → FeeConfig
isPaused() → bool
```

## 安全特性

1. **重入保护**：使用 OpenZeppelin 的 `ReentrancyGuard`
2. **访问控制**：多层级修饰符保护敏感操作
3. **整数溢出保护**：Solidity 0.8+ 内置检查 + unchecked 优化
4. **暂停机制**：紧急情况下可暂停核心功能
5. **CEI 模式**：Checks-Effects-Interactions 防止重入攻击
6. **Gas 优化**：
   - 使用 `unchecked` 块
   - 前缀自增 `++i`
   - Storage 打包优化
   - 批量操作限制（防止 gas 超限）

## 测试

```bash
# 运行所有测试
npx hardhat test

# 测试特定文件
npx hardhat test test/CourseContract.test.ts

# 测试覆盖率
npx hardhat coverage
```

## 项目结构

```
contract/
├── contracts/
│   ├── CourseContract.sol          # 主合约
│   ├── interfaces/                 # 接口定义
│   │   ├── ICourseContract.sol
│   │   ├── IEconomicModel.sol
│   │   └── IERC20.sol
│   ├── libraries/                  # 库文件
│   │   ├── CourseManagement.sol
│   │   ├── PaymentDistributor.sol
│   │   ├── ProgressTracker.sol
│   │   ├── PurchaseLogic.sol
│   │   ├── RefundLogic.sol
│   │   └── WithdrawalLogic.sol
│   ├── modules/                    # 功能模块
│   │   ├── PurchaseModule.sol
│   │   ├── QueryModule.sol
│   │   ├── RefundModule.sol
│   │   └── WithdrawalModule.sol
│   └── tokens/
│       └── SimpleYDToken.sol       # YD代币合约
├── ignition/
│   └── modules/                    # 部署脚本
│       ├── SimpleYDToken.ts
│       └── CourseContract.ts
├── test/                           # 测试文件
├── hardhat.config.ts               # Hardhat配置
├── package.json
└── README.md
```

## 经济模型

### 分账比例
- **讲师**：90%
- **平台**：10%
- **推荐人**：0%（预留字段）

### 退款计算
- **退款金额** = 原价 × 70%
- **平台损失** = 原价 × 10%（已分账给平台）
- **讲师扣除** = 原价 × 70%（从待提现余额扣除）

### 代币经济
- **总供应量**：1,000,000 YD
- **ETH 兑换率**：1 ETH = 4,000 YD
- **质押最小金额**：100 YD
- **提前解锁惩罚**：20% 本金

## 已知限制

1. **课程删除**：只能删除无学生购买的课程（软删除）
2. **退款次数**：每个学生对每门课程只能退款一次
3. **批量认证**：单次最多认证 100 个讲师（防止 gas 超限）
4. **提现冷却**：讲师提现有 1 天冷却期
5. **质押限制**：每个用户同时只能有一个活跃质押

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题，请在 GitHub 仓库提交 Issue。
