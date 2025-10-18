# 课程质量投票 DAO 系统 - 详细设计文档

## 1. 系统概述

### 1.1 项目背景

在 Web3 大学平台中，课程质量直接影响学生体验和平台声誉。为了建立一个去中心化的课程质量治理机制，我们设计了基于 DAO 的课程质量投票系统，允许 YD 代币持有者对课程质量进行投票，形成社区驱动的课程质量监管机制。

### 1.2 核心目标

- **去中心化治理**：让社区参与课程质量管理
- **激励机制**：奖励正确判断课程质量的投票者
- **惩罚机制**：防止恶意提案和投票
- **透明公开**：所有投票和结果链上可查
- **经济平衡**：通过代币锁定和奖励分配维持系统健康

### 1.3 设计原则

1. **代币权重投票**：投票权重与锁定的 YD 代币数量成正比
2. **一课程一提案**：每门课程同时只能有一个活跃提案
3. **押金机制**：发起提案需要支付押金，防止垃圾提案
4. **锁定机制**：投票时锁定代币，投票结束后根据结果分配奖励
5. **时间限制**：每个提案有固定的投票期限
6. **法定人数**：达到最低投票人数才能生效

---

## 2. 系统架构

### 2.1 合约结构

```
CourseDAO (主合约)
├── ICourseDAO (接口)
├── ReentrancyGuard (安全防护)
├── Pausable (紧急暂停)
├── YDToken (ERC20代币)
└── CourseContract (课程合约)
```

### 2.2 核心组件

#### 2.2.1 提案系统 (Proposal System)

- 提案创建
- 提案取消
- 提案执行
- 提案状态管理

#### 2.2.2 投票系统 (Voting System)

- 投票权验证
- 代币锁定
- 投票记录
- 投票计数

#### 2.2.3 奖励系统 (Reward System)

- 奖励池计算
- 奖励分配
- 奖励领取

#### 2.2.4 配置系统 (Configuration System)

- DAO 参数配置
- 权限管理
- 紧急暂停

---

## 3. 业务流程

### 3.1 完整业务流程图

```
[发起提案] → [社区投票] → [计算结果] → [执行提案] → [领取奖励]
     ↓            ↓            ↓            ↓            ↓
  锁定押金    锁定代币    确定胜负    下架课程    分配奖励
```

### 3.2 详细业务流程

#### 3.2.1 发起提案流程

```
用户发起提案
    ↓
验证课程存在
    ↓
检查是否已有活跃提案
    ↓
检查用户YD代币余额 >= 提案押金
    ↓
转移押金到合约
    ↓
创建提案记录
    ↓
设置投票开始/结束时间
    ↓
标记课程有活跃提案
    ↓
触发 ProposalCreated 事件
```

**关键参数**：

- `courseId`: 课程 ID
- `reason`: 发起原因（字符串描述）
- `proposalDeposit`: 提案押金（默认 1000 YD）

**验证逻辑**：

1. 课程必须存在（通过 CourseContract 验证）
2. 课程当前没有活跃提案
3. 用户余额 >= 提案押金
4. 原因字符串不为空

**状态变更**：

- 提案状态：`Active`
- 课程状态：`hasActiveProposal[courseId] = true`
- 押金：从用户账户转移到合约

---

#### 3.2.2 投票流程

```
用户选择提案投票
    ↓
验证提案处于Active状态
    ↓
验证投票期未结束
    ↓
验证用户未投过票
    ↓
验证用户投票权重 >= 最小投票权重
    ↓
验证用户YD余额 >= 投票权重
    ↓
锁定用户代币到合约
    ↓
记录投票信息
    ↓
更新提案投票计数
    ↓
触发 VoteCasted 事件
```

**投票选项**：

- `For (0)`: 支持课程（认为课程质量好）
- `Against (1)`: 反对课程（认为课程质量差）

**关键参数**：

- `proposalId`: 提案 ID
- `option`: 投票选项（For/Against）
- `votingPower`: 投票权重（锁定的 YD 代币数量）

**验证逻辑**：

1. 提案必须处于`Active`状态
2. 当前时间 < 投票结束时间
3. 用户未对该提案投过票
4. 投票权重 >= 最小投票权重（默认 100 YD）
5. 用户余额 >= 投票权重

**投票权重计算**：

```solidity
投票权重 = 用户锁定的YD代币数量
总投票权 = forVotes + againstVotes
```

**状态变更**：

- 投票记录：创建 VoteRecord
- 提案计数：forVotes 或 againstVotes 增加
- 用户状态：hasVoted[user][proposalId] = true
- 代币锁定：从用户账户转移到合约

---

#### 3.2.3 结束投票流程

```
投票期结束
    ↓
任何人调用 finalizeProposal
    ↓
验证投票期已结束
    ↓
验证提案处于Active状态
    ↓
计算总投票数
    ↓
检查是否达到法定人数
    ↓
计算反对票占比
    ↓
判断投票是否通过
    ↓
设置提案状态（Succeeded/Failed）
    ↓
计算奖励池
    ↓
解除课程活跃提案标记
    ↓
触发 ProposalFinalized 事件
```

**法定人数计算**：

```solidity
法定人数 = max(
    课程学生数 * quorumPercentage / 10000,
    minVotingPower
)
```

**通过条件**：

```solidity
1. 达到法定人数：totalVotes >= quorumRequired
2. 反对票占比 >= 通过阈值：
   againstVotes / totalVotes >= passThreshold (默认50%)
```

**提案状态判定**：

- `Succeeded`: 达到法定人数 且 反对票占比 >= 50%
- `Failed`: 未达到法定人数 或 反对票占比 < 50%

**奖励池计算**：

```solidity
if (提案通过) {
    失败方 = forVotes (支持课程的一方)
} else {
    失败方 = againstVotes (反对课程的一方)
}

奖励池 = 提案押金 + 失败方代币 * rewardPoolPercentage (80%)
剩余代币 = 失败方代币 * (1 - rewardPoolPercentage) (20%给平台)
```

---

#### 3.2.4 执行提案流程

```
提案状态为Succeeded
    ↓
管理员或任何人调用executeProposal
    ↓
验证提案已通过
    ↓
验证提案未执行过
    ↓
标记提案为已执行
    ↓
执行治理操作（如下架课程）
    ↓
触发 ProposalExecuted 事件
```

**执行操作**：

1. 将课程标记为"质量问题"
2. 可选：自动触发退款流程
3. 可选：通知讲师改进课程
4. 可选：冻结课程新购买

**注意**：当前版本中，执行操作需要 CourseContract 提供相应接口支持。

---

#### 3.2.5 领取奖励流程

```
投票结束且提案已完成
    ↓
用户调用 claimReward
    ↓
验证提案已完成（Succeeded/Failed/Executed）
    ↓
验证用户已投票
    ↓
验证未领取过奖励
    ↓
计算用户奖励
    ↓
标记已领取
    ↓
转账奖励到用户
    ↓
触发 RewardClaimed 事件
```

**奖励计算逻辑**：

1. **失败方（输家）**：

```solidity
奖励 = 本金（votingPower）
// 失败方只能取回本金，锁定的代币被没收进入奖励池
```

2. **胜利方（赢家）**：

```solidity
奖励 = 本金 + 奖励池分成

奖励池分成 = (用户投票权重 / 胜利方总投票权重) * 总奖励池

例如：
- 用户投票权重：1000 YD
- 胜利方总投票权重：10000 YD
- 总奖励池：5000 YD
- 用户奖励 = 1000 + (1000/10000) * 5000 = 1000 + 500 = 1500 YD
```

**收益率示例**：
假设提案通过（Against 胜利）：

- Against 总票数：10000 YD
- For 总票数：5000 YD
- 提案押金：1000 YD
- 奖励池百分比：80%

```
奖励池 = 1000 + 5000 * 80% = 5000 YD
Against方每投1 YD可获得：1 + 5000/10000 = 1.5 YD
收益率 = 50%
```

---

#### 3.2.6 取消提案流程

```
提案发起人想要取消
    ↓
验证调用者是提案发起人
    ↓
验证在24小时内
    ↓
验证无人投票
    ↓
验证提案处于Active状态
    ↓
设置提案状态为Canceled
    ↓
解除课程活跃提案标记
    ↓
退还押金给发起人
    ↓
触发 ProposalCanceled 事件
```

**取消条件**：

1. 只有提案发起人可以取消
2. 投票开始后 24 小时内
3. 没有任何人投票
4. 提案处于 Active 状态

**注意**：一旦有人投票，提案无法取消，必须等待投票结束。

---

## 4. 数据结构设计

### 4.1 提案结构 (Proposal)

```solidity
struct Proposal {
    uint256 id;                    // 提案ID
    uint256 courseId;              // 课程ID
    address proposer;              // 提案发起人
    string reason;                 // 发起原因/描述
    uint256 proposalDeposit;       // 提案押金
    uint256 createdAt;             // 创建时间
    uint256 votingStartTime;       // 投票开始时间
    uint256 votingEndTime;         // 投票结束时间
    uint256 forVotes;              // 支持票数（支持课程）
    uint256 againstVotes;          // 反对票数（反对课程）
    uint256 totalVotingPower;      // 总投票权重
    ProposalStatus status;         // 提案状态
    bool executed;                 // 是否已执行
}
```

### 4.2 投票记录 (VoteRecord)

```solidity
struct VoteRecord {
    address voter;                 // 投票人
    uint256 proposalId;            // 提案ID
    VoteOption option;             // 投票选项
    uint256 votingPower;           // 投票权重（锁定的代币数量）
    uint256 timestamp;             // 投票时间
    bool rewardClaimed;            // 是否已领取奖励
}
```

### 4.3 DAO 配置 (DAOConfig)

```solidity
struct DAOConfig {
    uint256 proposalDeposit;       // 提案押金（默认1000 YD）
    uint256 minVotingPower;        // 最小投票权重（默认100 YD）
    uint256 votingPeriod;          // 投票期限（默认7天）
    uint256 quorumPercentage;      // 法定人数百分比（默认10%）
    uint256 passThreshold;         // 通过阈值（默认50%）
    uint256 rewardPoolPercentage;  // 奖励池百分比（默认80%）
}
```

**参数说明**：

- `proposalDeposit`: 防止垃圾提案，提案失败押金进入奖励池
- `minVotingPower`: 防止刷票攻击，确保投票有成本
- `votingPeriod`: 给予充分时间让社区参与投票
- `quorumPercentage`: 确保投票代表性，防止少数人操纵
- `passThreshold`: 反对票需要超过 50%才能通过提案
- `rewardPoolPercentage`: 80%奖励胜利方，20%给平台作为收入

### 4.4 投票统计 (VoteStats)

```solidity
struct VoteStats {
    uint256 totalProposals;        // 总提案数
    uint256 activeProposals;       // 活跃提案数
    uint256 succeededProposals;    // 通过的提案数
    uint256 failedProposals;       // 失败的提案数
    uint256 totalVoters;           // 总投票人数
    uint256 totalRewardsDistributed; // 总分发奖励
}
```

---

## 5. 状态机设计

### 5.1 提案状态转换图

```
        [创建提案]
            ↓
        Pending
            ↓
        Active ←─────────→ Canceled
            ↓                (24h内无投票可取消)
    [投票期结束]
            ↓
      ┌─────┴─────┐
      ↓           ↓
  Succeeded    Failed
      ↓           ↓
  Executed    (结束)
      ↓
   (结束)
```

### 5.2 状态说明

| 状态      | 说明                           | 可执行操作             |
| --------- | ------------------------------ | ---------------------- |
| Pending   | 待投票（保留状态，当前未使用） | -                      |
| Active    | 投票中                         | 投票、取消（条件限制） |
| Succeeded | 投票通过                       | 执行提案、领取奖励     |
| Failed    | 投票失败                       | 领取奖励               |
| Canceled  | 已取消                         | 无                     |
| Executed  | 已执行                         | 领取奖励               |

---

## 6. 经济模型设计

### 6.1 代币流转

#### 6.1.1 发起提案

```
用户账户 → [1000 YD] → 合约地址
```

#### 6.1.2 投票锁定

```
投票人账户 → [votingPower YD] → 合约地址
```

#### 6.1.3 奖励分配（提案通过，Against 胜利）

```
奖励池来源：
- 提案押金：1000 YD
- For方押金：5000 YD * 80% = 4000 YD
- 总奖励池：5000 YD

分配：
- Against方（胜利方）：本金 + 奖励池按比例分配
- For方（失败方）：仅本金
- 平台：5000 YD * 20% = 1000 YD
```

### 6.2 激励机制

#### 6.2.1 投票激励

- **胜利方**：获得本金 + 奖励池分成（最高 50%收益）
- **失败方**：仅获得本金，锁定代币的 20%被没收

#### 6.2.2 提案激励

- **提案通过**：提案人押金进入奖励池，但如果提案人也投票且在胜利方，可以获得更多奖励
- **提案失败**：提案人损失押金

### 6.3 防作恶机制

#### 6.3.1 防刷票攻击

- 设置最小投票权重（100 YD）
- 每个地址只能投一次票
- 投票需要锁定真实代币

#### 6.3.2 防垃圾提案

- 提案押金较高（1000 YD）
- 每门课程同时只能有一个提案
- 24 小时冷静期可取消

#### 6.3.3 防女巫攻击

- 投票权重与代币数量成正比
- 大户投票成本高，但收益也成正比
- 设置法定人数，防止少数人操纵

### 6.4 参数平衡

| 参数         | 默认值  | 设计考量                           |
| ------------ | ------- | ---------------------------------- |
| 提案押金     | 1000 YD | 防止垃圾提案，但不至于阻碍正当提案 |
| 最小投票权重 | 100 YD  | 防止刷票，确保投票有成本           |
| 投票期限     | 7 天    | 给予充分时间让社区参与             |
| 法定人数     | 10%     | 确保投票有代表性                   |
| 通过阈值     | 50%     | 反对票需过半才能下架课程           |
| 奖励池比例   | 80%     | 激励正确投票，20%给平台维持运营    |

---

## 7. 安全性设计

### 7.1 访问控制

| 功能      | 权限要求               |
| --------- | ---------------------- |
| 创建提案  | 任何持有 YD 代币的用户 |
| 投票      | 任何持有 YD 代币的用户 |
| 结束投票  | 任何人（投票期结束后） |
| 执行提案  | 任何人（提案通过后）   |
| 领取奖励  | 投票参与者             |
| 取消提案  | 仅提案发起人           |
| 更新配置  | 仅管理员               |
| 暂停/恢复 | 仅管理员               |

### 7.2 安全机制

#### 7.2.1 重入攻击防护

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

function vote(...) external nonReentrant { ... }
function claimReward(...) external nonReentrant { ... }
```

#### 7.2.2 紧急暂停

```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";

function createProposal(...) external whenNotPaused { ... }
function vote(...) external whenNotPaused { ... }
```

#### 7.2.3 整数溢出防护

- 使用 Solidity 0.8.19，内置溢出检查
- 所有百分比计算使用基点（10000 = 100%）

#### 7.2.4 自定义错误

使用自定义错误节省 gas：

```solidity
error InvalidCourse();
error ProposalAlreadyExists();
error InsufficientDeposit();
// ...
```

### 7.3 审计检查清单

- [ ] 重入攻击防护
- [ ] 整数溢出检查
- [ ] 访问控制验证
- [ ] 代币转账安全
- [ ] 状态一致性
- [ ] 时间操纵防护
- [ ] Gas 优化
- [ ] 紧急暂停机制

---

## 8. 使用场景示例

### 8.1 场景一：发现低质量课程

**背景**：用户 Alice 购买了课程 ID=101 的课程，发现课程质量很差，内容过时，讲师不负责。

**流程**：

1. Alice 调用`createProposal(101, "课程内容过时，讲师不回复学生问题")`
2. 支付 1000 YD 押金
3. 提案创建成功，ID=1，投票期 7 天

### 8.2 场景二：社区投票

**投票参与者**：

- Bob：反对课程，投票 2000 YD（Against）
- Carol：反对课程，投票 3000 YD（Against）
- Dave：支持课程，投票 1500 YD（For）
- Eve：支持课程，投票 1000 YD（For）

**投票结果**：

- Against: 5000 YD
- For: 2500 YD
- 总投票: 7500 YD
- 反对占比: 66.7% > 50%

### 8.3 场景三：计算和领取奖励

**结束投票**：

```
总投票：7500 YD
法定人数：课程100个学生 * 10% = 10人（假设每人100 YD = 1000 YD）
7500 YD > 1000 YD ✓
反对占比：66.7% > 50% ✓
提案通过 (Succeeded)
```

**奖励池计算**：

```
失败方（For）：2500 YD
奖励池 = 1000 (押金) + 2500 * 80% = 1000 + 2000 = 3000 YD
平台收入 = 2500 * 20% = 500 YD
```

**奖励分配**：

```
Bob（Against 2000 YD）：
奖励 = 2000 + (2000/5000) * 3000 = 2000 + 1200 = 3200 YD
收益率 = (3200-2000)/2000 = 60%

Carol（Against 3000 YD）：
奖励 = 3000 + (3000/5000) * 3000 = 3000 + 1800 = 4800 YD
收益率 = (4800-3000)/3000 = 60%

Dave（For 1500 YD）：
奖励 = 1500 YD（仅本金）
损失 = 0 YD

Eve（For 1000 YD）：
奖励 = 1000 YD（仅本金）
损失 = 0 YD

Alice（提案人，假设也投了Against 1000 YD）：
奖励 = 本金0（已作为押金） + (0/5000) * 3000 = 0 YD
（如果Alice没有投票，损失1000 YD押金）
```

### 8.4 场景四：执行提案

**执行操作**：

```solidity
executeProposal(1);
// 触发课程下架或质量标记
// 可能触发自动退款给所有购买学生
```

---

## 9. 前端集成指南

### 9.1 创建提案

```javascript
// 1. 授权DAO合约使用YD代币
await ydToken.approve(daoAddress, proposalDeposit)

// 2. 创建提案
await courseDAO.createProposal(courseId, '课程质量差，内容过时')
```

### 9.2 投票

```javascript
// 1. 授权DAO合约
const votingPower = ethers.parseEther('1000') // 1000 YD
await ydToken.approve(daoAddress, votingPower)

// 2. 投票
await courseDAO.vote(
  proposalId,
  1, // VoteOption.Against
  votingPower
)
```

### 9.3 查询提案状态

```javascript
const proposal = await courseDAO.getProposal(proposalId)
console.log('提案状态:', proposal.status)
console.log('支持票:', ethers.formatEther(proposal.forVotes))
console.log('反对票:', ethers.formatEther(proposal.againstVotes))
```

### 9.4 领取奖励

```javascript
// 1. 查询可领取奖励
const reward = await courseDAO.calculateReward(userAddress, proposalId)
console.log('可领取奖励:', ethers.formatEther(reward))

// 2. 领取
await courseDAO.claimReward(proposalId)
```

---

## 10. Gas 优化策略

### 10.1 存储优化

- 使用`mapping`而非数组存储大量数据
- 使用`uint256`避免类型转换
- 使用自定义错误而非`require`字符串

### 10.2 计算优化

- 避免循环中的重复计算
- 使用`immutable`和`constant`
- 批量操作而非单次操作

### 10.3 事件优化

- 使用`indexed`参数提高查询效率
- 关键数据记录在事件中，减少链上存储

---

## 11. 升级和维护

### 11.1 参数调整

管理员可以根据实际运营情况调整 DAO 参数：

```solidity
updateDAOConfig(
    2000 * 1e18,  // 提高提案押金
    200 * 1e18,   // 提高最小投票权重
    10 days,      // 延长投票期
    2000,         // 提高法定人数到20%
    6000,         // 提高通过阈值到60%
    9000          // 提高奖励池比例到90%
);
```

### 11.2 紧急暂停

遇到安全问题时：

```solidity
await courseDAO.pause(); // 暂停所有操作
// 修复问题后
await courseDAO.unpause(); // 恢复操作
```

### 11.3 合约升级

如需升级合约功能，可采用代理模式：

1. 部署新版本 CourseDAO
2. 迁移数据和奖励池
3. 更新前端调用地址

---

## 12. 测试用例

### 12.1 单元测试

#### 测试 1：创建提案

```javascript
it('应该成功创建提案', async () => {
  await ydToken.approve(dao.address, proposalDeposit)
  const tx = await dao.createProposal(courseId, '质量差')
  expect(tx).to.emit(dao, 'ProposalCreated')
})
```

#### 测试 2：投票

```javascript
it('应该成功投票', async () => {
  const votingPower = ethers.parseEther('1000')
  await ydToken.approve(dao.address, votingPower)
  await dao.vote(proposalId, 1, votingPower)

  const proposal = await dao.getProposal(proposalId)
  expect(proposal.againstVotes).to.equal(votingPower)
})
```

#### 测试 3：领取奖励

```javascript
it('胜利方应该获得奖励', async () => {
  // 投票并结束
  await time.increase(7 * 24 * 60 * 60) // 7天后
  await dao.finalizeProposal(proposalId)

  // 领取奖励
  const beforeBalance = await ydToken.balanceOf(user.address)
  await dao.claimReward(proposalId)
  const afterBalance = await ydToken.balanceOf(user.address)

  expect(afterBalance).to.be.gt(beforeBalance)
})
```

### 12.2 集成测试

测试完整流程：创建提案 → 多人投票 → 结束投票 → 领取奖励

### 12.3 安全测试

- 重入攻击测试
- 权限控制测试
- 边界条件测试
- Gas 消耗测试

---

## 13. 部署指南

### 13.1 部署顺序

1. 部署 YDToken（如已部署则跳过）
2. 部署 CourseContract（如已部署则跳过）
3. 部署 CourseDAO
4. 配置权限和参数

### 13.2 部署脚本

```javascript
const { ethers } = require('hardhat')

async function main() {
  // 获取合约地址
  const ydTokenAddress = '0x...'
  const courseContractAddress = '0x...'

  // 部署DAO
  const CourseDAO = await ethers.getContractFactory('CourseDAO')
  const dao = await CourseDAO.deploy(ydTokenAddress, courseContractAddress)
  await dao.waitForDeployment()

  console.log('CourseDAO deployed to:', await dao.getAddress())

  // 配置参数（可选）
  await dao.updateDAOConfig(
    ethers.parseEther('1000'), // 1000 YD押金
    ethers.parseEther('100'), // 100 YD最小投票
    7 * 24 * 60 * 60, // 7天投票期
    1000, // 10%法定人数
    5000, // 50%通过阈值
    8000 // 80%奖励池
  )
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
```

---

## 14. 常见问题 (FAQ)

### Q1: 为什么要设置提案押金？

**A**: 防止垃圾提案泛滥，确保提案人有充分理由和信心发起提案。

### Q2: 投票失败方会损失代币吗？

**A**: 失败方不会直接损失本金，但会损失代币的机会成本（锁定 7 天）。失败方的 20%代币会被没收，80%进入奖励池分配给胜利方。

### Q3: 如何防止大户操纵投票？

**A**:

1. 设置法定人数，需要足够多人参与
2. 投票权重与代币成正比，大户投票成本也高
3. 通过阈值设置为 50%，需要过半反对才能通过

### Q4: 提案押金会退还吗？

**A**:

- 提案通过（Succeeded）：押金进入奖励池，不退还
- 提案失败（Failed）：押金进入奖励池，不退还
- 提案取消（Canceled）：押金退还

### Q5: 可以对同一课程发起多个提案吗？

**A**: 不可以，每门课程同时只能有一个活跃提案，必须等当前提案结束后才能发起新提案。

### Q6: 投票期间可以撤回投票吗？

**A**: 不可以，一旦投票，代币会被锁定直到投票结束并领取奖励。

### Q7: 如果没人投票怎么办？

**A**: 投票期结束后，任何人可以调用`finalizeProposal`，如果未达到法定人数，提案状态变为`Failed`。

### Q8: 奖励什么时候可以领取？

**A**: 在投票结束并调用`finalizeProposal`后，所有参与投票的用户都可以领取奖励。

---

## 15. 未来扩展

### 15.1 委托投票

允许用户将投票权委托给信任的人：

```solidity
function delegate(address delegatee) external;
function voteBySig(uint256 proposalId, VoteOption option, ...) external;
```

### 15.2 分级投票权

根据用户持有时间或质押情况给予不同权重：

```solidity
votingPower = baseTokens * timeMultiplier * stakeMultiplier
```

### 15.3 多签执行

重要提案需要多个管理员签名才能执行：

```solidity
function executeProposalWithMultisig(...) external;
```

### 15.4 链下投票

使用链下签名减少 gas 消耗，仅在最后上链结果：

```solidity
function finalizeProposalWithSignatures(bytes[] signatures) external;
```

### 15.5 自动执行

提案通过后自动触发课程合约操作：

```solidity
interface ICourseContract {
    function markCourseAsLowQuality(uint256 courseId) external;
    function triggerRefundForCourse(uint256 courseId) external;
}
```

---

## 16. 总结

CourseDAO 是一个完整的去中心化课程质量治理系统，通过代币投票机制实现社区驱动的课程监管。系统设计充分考虑了：

1. **经济激励**：胜利方获得奖励，失败方损失代币
2. **安全性**：防止各类攻击，保护用户资产
3. **公平性**：投票权重与代币持有成正比
4. **透明性**：所有操作链上可查
5. **可扩展性**：支持未来功能扩展

该系统可以有效提升课程质量，保护学生权益，建立健康的教育生态。

---

## 附录 A：合约接口速查

### 核心函数

| 函数             | 参数                            | 返回值     | 说明     |
| ---------------- | ------------------------------- | ---------- | -------- |
| createProposal   | courseId, reason                | proposalId | 创建提案 |
| vote             | proposalId, option, votingPower | -          | 投票     |
| finalizeProposal | proposalId                      | -          | 结束投票 |
| executeProposal  | proposalId                      | -          | 执行提案 |
| claimReward      | proposalId                      | -          | 领取奖励 |
| cancelProposal   | proposalId                      | -          | 取消提案 |

### 查询函数

| 函数              | 参数              | 返回值                | 说明          |
| ----------------- | ----------------- | --------------------- | ------------- |
| getProposal       | proposalId        | Proposal              | 获取提案信息  |
| getVoteRecord     | voter, proposalId | VoteRecord            | 获取投票记录  |
| getCourseProposal | courseId          | proposalId, hasActive | 获取课程提案  |
| calculateReward   | voter, proposalId | reward                | 计算奖励      |
| canVote           | voter, proposalId | bool                  | 是否可投票    |
| getDAOConfig      | -                 | DAOConfig             | 获取 DAO 配置 |

---

## 附录 B：事件列表

| 事件              | 参数                                                           | 说明     |
| ----------------- | -------------------------------------------------------------- | -------- |
| ProposalCreated   | proposalId, courseId, proposer, reason, deposit, votingEndTime | 提案创建 |
| VoteCasted        | proposalId, voter, option, votingPower, timestamp              | 投票     |
| ProposalFinalized | proposalId, status, forVotes, againstVotes, rewardPool         | 投票结束 |
| ProposalExecuted  | proposalId, courseId, courseRemoved                            | 提案执行 |
| RewardClaimed     | proposalId, voter, reward                                      | 奖励领取 |
| ProposalCanceled  | proposalId, proposer                                           | 提案取消 |

---

**文档版本**: 1.0
**最后更新**: 2025-01-18
**作者**: Web3 大学开发团队
