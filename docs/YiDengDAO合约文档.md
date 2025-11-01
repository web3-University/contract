# YiDengDAO 合约文档

## 合约概述

YiDengDAO 是一个基于 DAO（去中心化自治组织）的投票治理合约，允许持有 YD 代币的用户创建提案和参与投票。合约采用"一人一票"的投票机制，胜诉方投票者将获得奖励，败诉方不受惩罚。提案创建者需要质押 YD 代币，投票结束后质押将被退还。

---

## 合约信息

- **合约名称**: YiDengDAO
- **Solidity 版本**: ^0.8.28
- **许可证**: MIT
- **依赖**: OpenZeppelin Contracts (Ownable, IERC20)

---

## 核心功能

### 1. 创建提案

```solidity
function createProposal(string memory _proposalId) external
```

- **功能**: 创建新的投票提案
- **权限**: 任何持有足够 YD 代币的用户
- **参数**:
  - `_proposalId`: 提案的唯一标识符（字符串类型）
- **前置条件**:
  - 提案 ID 不能为空
  - 提案 ID 不能重复
  - 调用者必须持有足够的 YD 代币用于质押
  - 调用者必须授权合约转移质押代币
- **质押机制**: 创建提案需要质押指定数量的 YD 代币到合约
- **事件**: 触发 `ProposalCreated` 事件

### 2. 投票

```solidity
function vote(string memory _proposalId, bool _support) external
```

- **功能**: 对指定提案进行投票
- **权限**: 任何持有 YD 代币的用户
- **参数**:
  - `_proposalId`: 要投票的提案 ID
  - `_support`: 投票选择（true 为赞成，false 为反对）
- **投票机制**: 每个账户只能投 1 票，投票权重固定为 1
- **前置条件**:
  - 提案必须存在
  - 提案未被执行
  - 在投票期内（7 天内）
  - 投票者未投过票
  - 投票者持有 YD 代币（余额 > 0）
- **事件**: 触发 `Voted` 事件

### 3. 执行提案并分发奖励

```solidity
function executeProposalAndDistributeRewards(string memory _proposalId, uint256 _rewardAmount) external onlyOwner
```

- **功能**: 执行提案、判定结果、分发奖励并退还质押
- **权限**: 仅合约所有者
- **参数**:
  - `_proposalId`: 要执行的提案 ID
  - `_rewardAmount`: 每个胜诉方投票者获得的奖励金额
- **执行流程**:
  1. 检查投票期是否已结束
  2. 判断提案是否通过（赞成票 > 反对票）
  3. 退还质押给提案创建者
  4. 向胜诉方投票者分发奖励
- **前置条件**:
  - 提案必须存在
  - 提案未被执行
  - 投票期已结束（超过 7 天）
  - 合约有足够的代币用于奖励分发
- **事件**: 触发 `ProposalExecuted`、`StakeReturned`、`RewardDistributed` 事件

### 4. 查询提案信息

```solidity
function getProposal(string memory _proposalId) external view returns (
    string memory id,
    uint256 timestamp,
    uint256 votesFor,
    uint256 votesAgainst,
    bool executed
)
```

- **功能**: 获取提案的基本信息
- **参数**: `_proposalId` - 提案 ID
- **返回值**:
  - `id`: 提案 ID
  - `timestamp`: 提案创建时间戳
  - `votesFor`: 赞成票数
  - `votesAgainst`: 反对票数
  - `executed`: 是否已执行

### 5. 检查投票状态

```solidity
function hasVoted(string memory _proposalId, address _voter) external view returns (bool)
```

- **功能**: 检查指定地址是否已对某提案投票
- **参数**:
  - `_proposalId`: 提案 ID
  - `_voter`: 要查询的地址
- **返回值**: 已投票返回 true，否则返回 false

### 6. 获取投票者列表

```solidity
function getProposalVoters(string memory _proposalId) external view returns (address[] memory)
```

- **功能**: 获取某提案的所有投票者地址列表
- **参数**: `_proposalId` - 提案 ID
- **返回值**: 投票者地址数组

### 7. 获取所有提案 ID

```solidity
function getAllProposalIds() external view returns (string[] memory)
```

- **功能**: 获取所有提案 ID 列表
- **返回值**: 提案 ID 字符串数组

### 8. 获取提案总数

```solidity
function getProposalCount() external view returns (uint256)
```

- **功能**: 获取提案总数
- **返回值**: 提案数量

### 9. 设置质押金额

```solidity
function setStakeAmount(uint256 _stakeAmount) external onlyOwner
```

- **功能**: 设置创建提案所需的质押金额
- **权限**: 仅合约所有者
- **参数**: `_stakeAmount` - 新的质押金额

---

## 数据结构

### Proposal 结构体

```solidity
struct Proposal {
    string id;                          // 提案的唯一标识符
    uint256 timestamp;                  // 提案创建时间戳
    uint256 votesFor;                   // 赞成票数
    uint256 votesAgainst;               // 反对票数
    bool executed;                      // 是否已执行
    mapping(address => bool) hasVoted;  // 地址是否已投票
    mapping(address => bool) votedFor;  // 地址是否投赞成票
    address creator;                    // 提案创建者地址
    uint256 stakeAmount;                // 质押的代币数量
    bool exists;                        // 提案是否存在
}
```

---

## 状态变量

| 变量名 | 类型 | 可见性 | 说明 |
|--------|------|--------|------|
| `ydToken` | IERC20 | public | YD 代币合约接口 |
| `proposals` | mapping(string => Proposal) | public | 提案 ID 到提案数据的映射 |
| `proposalVoters` | mapping(string => address[]) | public | 提案 ID 到投票者地址数组的映射 |
| `proposalIds` | string[] | public | 所有提案 ID 的列表 |
| `votingDuration` | uint256 | public | 投票持续时间（7 天） |
| `stakeAmount` | uint256 | public | 创建提案所需质押的 YD 代币数量 |

---

## 事件

### ProposalCreated

```solidity
event ProposalCreated(
    string indexed proposalId,
    uint256 timestamp,
    address indexed creator,
    uint256 stakeAmount
)
```

- **触发时机**: 新提案创建时
- **参数**:
  - `proposalId`: 提案 ID
  - `timestamp`: 创建时间
  - `creator`: 创建者地址
  - `stakeAmount`: 质押金额

### Voted

```solidity
event Voted(string indexed proposalId, address indexed voter, bool support)
```

- **触发时机**: 用户投票时
- **参数**:
  - `proposalId`: 提案 ID
  - `voter`: 投票者地址
  - `support`: 是否支持（true 为赞成，false 为反对）

### ProposalExecuted

```solidity
event ProposalExecuted(string indexed proposalId, bool passed)
```

- **触发时机**: 提案执行时
- **参数**:
  - `proposalId`: 提案 ID
  - `passed`: 提案是否通过

### RewardDistributed

```solidity
event RewardDistributed(
    string indexed proposalId,
    address indexed voter,
    uint256 amount
)
```

- **触发时机**: 向胜诉方投票者分发奖励时
- **参数**:
  - `proposalId`: 提案 ID
  - `voter`: 获得奖励的投票者地址
  - `amount`: 奖励金额

### StakeReturned

```solidity
event StakeReturned(
    string indexed proposalId,
    address indexed creator,
    uint256 amount
)
```

- **触发时机**: 向提案创建者退还质押时
- **参数**:
  - `proposalId`: 提案 ID
  - `creator`: 提案创建者地址
  - `amount`: 退还的质押金额

---

## 权限控制

合约使用 OpenZeppelin 的 `Ownable` 模式进行权限管理：

| 功能 | 权限要求 |
|------|----------|
| 创建提案 | 任何持有足够 YD 代币的用户 |
| 投票 | 任何持有 YD 代币的用户 |
| 执行提案并分发奖励 | 仅合约所有者 |
| 设置质押金额 | 仅合约所有者 |
| 查询功能 | 任何人（view 函数） |

---

## 使用流程

### 完整工作流程

```
1. 部署合约
   ↓
2. 用户授权合约转移 YD 代币
   ↓
3. 用户创建提案（质押 YD 代币）
   ↓
4. 其他用户在 7 天内投票
   ↓
5. 投票期结束后，所有者执行提案
   ↓
6. 自动分发奖励给胜诉方
   ↓
7. 退还质押给提案创建者
```

### 创建提案示例

```solidity
// 1. 用户授权合约转移代币
ydToken.approve(daoAddress, stakeAmount);

// 2. 创建提案
dao.createProposal("proposal-001");
```

### 投票示例

```solidity
// 投赞成票
dao.vote("proposal-001", true);

// 投反对票
dao.vote("proposal-001", false);
```

### 执行提案示例

```solidity
// 所有者执行提案，每个胜诉方获得 100 YD 奖励
dao.executeProposalAndDistributeRewards("proposal-001", 100 * 10**18);
```

---

## 投票机制详解

### 投票权重

- **一人一票**: 每个账户的投票权重固定为 1 票
- **持币要求**: 只需持有任意数量的 YD 代币即可投票（余额 > 0）
- **唯一性**: 每个地址对同一提案只能投票一次

### 投票期限

- **投票时长**: 从提案创建时开始，持续 7 天
- **计算方式**: `block.timestamp <= proposal.timestamp + 7 days`

### 提案通过条件

- **判定规则**: 赞成票数 > 反对票数
- **公式**: `votesFor > votesAgainst`

### 奖励分配规则

**胜诉方定义**:
- 提案通过（赞成票多）且投了赞成票的投票者
- 提案未通过（反对票多）且投了反对票的投票者

**败诉方**:
- 不受任何惩罚，不扣除代币
- 只是不获得奖励

**奖励来源**:
- 由合约所有者在执行提案时提供
- 需要确保合约有足够的 YD 代币余额

---

## 质押机制

### 质押要求

- **质押对象**: 提案创建者
- **质押金额**: 由 `stakeAmount` 状态变量决定
- **质押时机**: 创建提案时
- **质押去向**: 转移到合约地址

### 质押退还

- **退还时机**: 提案执行时
- **退还对象**: 提案创建者
- **退还金额**: 完整的质押金额
- **退还条件**: 无论提案是否通过，质押都会退还

### 质押作用

1. **防止垃圾提案**: 需要质押代币才能创建提案
2. **确保责任**: 创建者需要承担一定的经济成本
3. **激励机制**: 质押会退还，不会造成损失

---

## 安全特性

1. **权限隔离**: 执行提案和设置参数仅限所有者
2. **重入保护**: 使用 checks-effects-interactions 模式
3. **输入验证**: 所有关键函数都包含完整的输入验证
4. **状态检查**: 严格检查提案状态、投票期限等
5. **唯一性保证**: 
   - 提案 ID 不可重复
   - 每个地址只能投票一次
6. **事件记录**: 所有关键操作都触发事件，便于追踪和审计
7. **标准继承**: 使用 OpenZeppelin 经过审计的合约库

---

## Gas 优化建议

### 当前设计的 Gas 考量

1. **字符串作为 Key**: 使用字符串作为提案 ID 比 uint256 消耗更多 Gas
2. **数组遍历**: `executeProposalAndDistributeRewards` 需要遍历所有投票者
3. **存储优化**: 使用 mapping 存储投票状态，避免重复遍历

### 潜在优化方向

1. **考虑使用 uint256 作为提案 ID**: 可以节省 Gas，但会降低可读性
2. **批量处理**: 对于投票者众多的提案，可以考虑分批执行
3. **缓存数组长度**: 在循环中缓存 `voters.length`

---

## 注意事项

⚠️ **重要提示**:

1. **代币准备**:
   - 创建提案前必须授权合约转移质押代币
   - 执行提案前合约必须有足够代币用于奖励分发

2. **投票期限**:
   - 投票期固定为 7 天，不可修改单个提案的投票期
   - 投票期结束前无法执行提案

3. **提案 ID 管理**:
   - 提案 ID 一旦创建不可修改
   - 建议使用有意义的命名规范（如 "proposal-001"）

4. **奖励金额**:
   - 所有者在执行提案时需要计算合理的奖励金额
   - 确保合约有足够的代币余额

5. **质押金额调整**:
   - 只能通过 `setStakeAmount` 修改
   - 修改后只影响新创建的提案，不影响已存在的提案

6. **Gas 费用**:
   - 投票者众多时，执行提案的 Gas 费用会很高
   - 建议监控提案的投票者数量

7. **安全审计**:
   - 建议在主网部署前进行完整的安全审计
   - 特别关注奖励分发逻辑和权限控制

---

## 示例场景

### 场景 1: 社区决策投票

```solidity
// 1. 创建提案：是否增加社区基金
dao.createProposal("increase-community-fund");

// 2. 社区成员投票
// Alice 投赞成票
dao.vote("increase-community-fund", true);

// Bob 投赞成票
dao.vote("increase-community-fund", true);

// Charlie 投反对票
dao.vote("increase-community-fund", false);

// 3. 7 天后，所有者执行提案
// 提案通过（2 票赞成 vs 1 票反对）
// Alice 和 Bob 获得奖励
dao.executeProposalAndDistributeRewards("increase-community-fund", 100 * 10**18);
```

### 场景 2: 协议升级投票

```solidity
// 1. 创建升级提案
dao.createProposal("protocol-upgrade-v2");

// 2. 投票
dao.vote("protocol-upgrade-v2", true);  // 赞成
dao.vote("protocol-upgrade-v2", false); // 反对

// 3. 查询提案信息
(string memory id, uint256 timestamp, uint256 votesFor, uint256 votesAgainst, bool executed) 
    = dao.getProposal("protocol-upgrade-v2");

// 4. 检查是否已投票
bool hasVoted = dao.hasVoted("protocol-upgrade-v2", userAddress);

// 5. 执行提案
dao.executeProposalAndDistributeRewards("protocol-upgrade-v2", 50 * 10**18);
```

---

## 合约交互流程图

```
用户 A (创建者)                    YiDengDAO 合约                    用户 B/C (投票者)
     |                                  |                                    |
     |--[1] approve(dao, stake)-------->|                                    |
     |                                  |                                    |
     |--[2] createProposal()----------->|                                    |
     |                                  |--[质押代币]                        |
     |                                  |--[记录提案]                        |
     |                                  |                                    |
     |                                  |<--[3] vote(true/false)-------------|
     |                                  |--[记录投票]                        |
     |                                  |                                    |
     |                                  |<--[4] vote(true/false)-------------|
     |                                  |--[记录投票]                        |
     |                                  |                                    |
     |                             [7 天投票期]                             |
     |                                  |                                    |
所有者|--[5] executeProposal()---------->|                                    |
     |                                  |--[退还质押]------------------>     |
     |                                  |--[分发奖励]------------------------->|
     |                                  |                                    |
```

---

## 合约地址

- **网络**: [待部署]
- **合约地址**: [待部署]
- **所有者地址**: [待部署]
- **YD 代币地址**: [待配置]

---

## 版本历史

- **v1.0**: 初始版本
  - 支持提案创建和投票
  - 一人一票投票机制
  - 质押机制
  - 自动奖励分发
  - 胜诉方奖励，败诉方不惩罚

---

## 相关链接

- **OpenZeppelin 文档**: https://docs.openzeppelin.com/contracts/
- **Solidity 文档**: https://docs.soliditylang.org/
- **DAO 最佳实践**: https://github.com/OpenZeppelin/openzeppelin-contracts

---

## 常见问题 (FAQ)

### Q1: 为什么使用"一人一票"而不是按代币数量投票？

A: 这种设计是为了防止"鲸鱼"（大户）垄断投票，确保社区的公平性和去中心化。

### Q2: 败诉方为什么不受惩罚？

A: 为了鼓励社区成员积极参与投票，不惩罚少数派，营造更友好的治理环境。

### Q3: 质押的代币会被没收吗？

A: 不会。质押只是为了防止垃圾提案，投票结束后会全额退还给提案创建者。

### Q4: 如果没有人投票会怎样？

A: 提案仍然可以执行，但由于 `votesFor = 0` 和 `votesAgainst = 0`，提案不会通过（因为不满足 `votesFor > votesAgainst`）。

### Q5: 奖励代币从哪里来？

A: 由合约所有者在执行提案时提供。建议提前向合约地址转入足够的 YD 代币作为奖励池。

### Q6: 可以修改投票期限吗？

A: `votingDuration` 目前是固定的 7 天。如需修改，需要在合约中添加相应的设置函数（需要重新部署或升级合约）。

### Q7: 提案创建者可以对自己的提案投票吗？

A: 可以。只要创建者持有 YD 代币且未投过票，就可以投票。

### Q8: 如果合约代币余额不足以支付奖励怎么办？

A: 交易会失败并回滚，提案不会被标记为已执行。所有者需要先向合约转入足够的代币。