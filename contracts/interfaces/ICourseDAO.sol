// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICourseDAO
 * @dev 课程质量投票DAO接口定义
 * @notice 允许YD代币持有者对课程质量进行投票治理
 */
interface ICourseDAO {

    // ==================== 枚举类型 ====================

    /**
     * @dev 提案状态
     */
    enum ProposalStatus {
        Pending,      // 待投票
        Active,       // 投票中
        Succeeded,    // 投票通过（反对课程成功）
        Failed,       // 投票失败（支持课程）
        Canceled,     // 已取消
        Executed      // 已执行
    }

    /**
     * @dev 投票选项
     */
    enum VoteOption {
        Against,      // 反对课程（认为课程质量差）
        For           // 支持课程（认为课程质量好）
    }

    // ==================== 数据结构 ====================

    /**
     * @dev 提案信息
     */
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

    /**
     * @dev 投票记录
     */
    struct VoteRecord {
        address voter;                 // 投票人
        uint256 proposalId;            // 提案ID
        VoteOption option;             // 投票选项
        uint256 votingPower;           // 投票权重（锁定的代币数量）
        uint256 timestamp;             // 投票时间
        bool rewardClaimed;            // 是否已领取奖励
    }

    /**
     * @dev DAO配置参数
     */
    struct DAOConfig {
        uint256 proposalDeposit;       // 提案押金（YD代币）
        uint256 minVotingPower;        // 最小投票权重
        uint256 votingPeriod;          // 投票期限（秒）
        uint256 quorumPercentage;      // 法定人数百分比（基点，10000=100%）
        uint256 passThreshold;         // 通过阈值（基点，10000=100%）
        uint256 rewardPoolPercentage;  // 奖励池百分比（失败方押金的百分比）
    }

    /**
     * @dev 投票统计
     */
    struct VoteStats {
        uint256 totalProposals;        // 总提案数
        uint256 activeProposals;       // 活跃提案数
        uint256 succeededProposals;    // 通过的提案数
        uint256 failedProposals;       // 失败的提案数
        uint256 totalVoters;           // 总投票人数
        uint256 totalRewardsDistributed; // 总分发奖励
    }

    // ==================== 事件定义 ====================

    /**
     * @dev 提案创建事件
     */
    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 indexed courseId,
        address indexed proposer,
        string reason,
        uint256 deposit,
        uint256 votingEndTime
    );

    /**
     * @dev 投票事件
     */
    event VoteCasted(
        uint256 indexed proposalId,
        address indexed voter,
        VoteOption option,
        uint256 votingPower,
        uint256 timestamp
    );

    /**
     * @dev 提案完成事件
     */
    event ProposalFinalized(
        uint256 indexed proposalId,
        ProposalStatus status,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 rewardPool
    );

    /**
     * @dev 提案执行事件
     */
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 indexed courseId,
        bool courseRemoved
    );

    /**
     * @dev 奖励领取事件
     */
    event RewardClaimed(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 reward
    );

    /**
     * @dev 提案取消事件
     */
    event ProposalCanceled(
        uint256 indexed proposalId,
        address indexed proposer
    );

    /**
     * @dev DAO配置更新事件
     */
    event DAOConfigUpdated(
        uint256 proposalDeposit,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 passThreshold
    );

    // ==================== 核心功能 ====================

    /**
     * @dev 创建提案
     * @param courseId 课程ID
     * @param reason 发起原因
     * @return proposalId 提案ID
     */
    function createProposal(
        uint256 courseId,
        string memory reason
    ) external returns (uint256 proposalId);

    /**
     * @dev 投票
     * @param proposalId 提案ID
     * @param option 投票选项
     * @param votingPower 投票权重（锁定的YD代币数量）
     */
    function vote(
        uint256 proposalId,
        VoteOption option,
        uint256 votingPower
    ) external;

    /**
     * @dev 结束投票并计算结果
     * @param proposalId 提案ID
     */
    function finalizeProposal(uint256 proposalId) external;

    /**
     * @dev 执行提案（下架课程）
     * @param proposalId 提案ID
     */
    function executeProposal(uint256 proposalId) external;

    /**
     * @dev 领取投票奖励
     * @param proposalId 提案ID
     */
    function claimReward(uint256 proposalId) external;

    /**
     * @dev 取消提案（仅提案人在投票开始前可取消）
     * @param proposalId 提案ID
     */
    function cancelProposal(uint256 proposalId) external;

    // ==================== 查询功能 ====================

    /**
     * @dev 获取提案信息
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (Proposal memory);

    /**
     * @dev 获取用户投票记录
     */
    function getVoteRecord(address voter, uint256 proposalId)
        external
        view
        returns (VoteRecord memory);

    /**
     * @dev 获取课程的提案ID（如果存在）
     */
    function getCourseProposal(uint256 courseId)
        external
        view
        returns (uint256 proposalId, bool hasActiveProposal);

    /**
     * @dev 计算用户可领取的奖励
     */
    function calculateReward(address voter, uint256 proposalId)
        external
        view
        returns (uint256 reward);

    /**
     * @dev 获取DAO配置
     */
    function getDAOConfig() external view returns (DAOConfig memory);

    /**
     * @dev 获取投票统计
     */
    function getVoteStats() external view returns (VoteStats memory);

    /**
     * @dev 检查用户是否可以投票
     */
    function canVote(address voter, uint256 proposalId)
        external
        view
        returns (bool);

    /**
     * @dev 获取所有提案ID列表
     */
    function getAllProposals() external view returns (uint256[] memory);

    /**
     * @dev 获取活跃提案列表
     */
    function getActiveProposals() external view returns (uint256[] memory);

    /**
     * @dev 获取用户参与的提案列表
     */
    function getUserProposals(address user)
        external
        view
        returns (uint256[] memory);

    // ==================== 管理功能 ====================

    /**
     * @dev 更新DAO配置（仅管理员）
     */
    function updateDAOConfig(
        uint256 proposalDeposit,
        uint256 minVotingPower,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 passThreshold,
        uint256 rewardPoolPercentage
    ) external;

    /**
     * @dev 暂停DAO（紧急情况）
     */
    function pause() external;

    /**
     * @dev 恢复DAO
     */
    function unpause() external;
}
