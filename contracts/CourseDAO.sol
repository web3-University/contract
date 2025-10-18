// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/ICourseDAO.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICourseContract.sol";

/**
 * @title CourseDAO
 * @dev 课程质量投票DAO合约
 * @notice 允许YD代币持有者对课程质量进行投票治理
 */
contract CourseDAO is ICourseDAO, ReentrancyGuard, Pausable {

    // ==================== 自定义错误 ====================

    error InvalidCourse();
    error ProposalAlreadyExists();
    error InsufficientDeposit();
    error ProposalNotFound();
    error VotingNotActive();
    error AlreadyVoted();
    error InsufficientVotingPower();
    error NotProposer();
    error VotingNotEnded();
    error VotingAlreadyEnded();
    error ProposalNotSucceeded();
    error ProposalAlreadyExecuted();
    error NoRewardToClaim();
    error OnlyAdmin();
    error InvalidConfig();
    error CannotCancelNow();

    // ==================== 状态变量 ====================

    IERC20 public immutable ydToken;                    // YD代币合约
    ICourseContract public immutable courseContract;    // 课程合约
    address public admin;                               // 管理员地址

    uint256 public proposalCount;                       // 提案计数器
    DAOConfig public daoConfig;                         // DAO配置

    // 提案数据
    mapping(uint256 => Proposal) public proposals;      // 提案ID => 提案信息
    mapping(uint256 => uint256) public courseProposals; // 课程ID => 提案ID
    mapping(uint256 => bool) public hasActiveProposal;  // 课程ID => 是否有活跃提案

    // 投票数据
    mapping(address => mapping(uint256 => VoteRecord)) public voteRecords; // 用户 => 提案ID => 投票记录
    mapping(address => mapping(uint256 => bool)) public hasVoted;          // 用户 => 提案ID => 是否已投票

    // 奖励池
    mapping(uint256 => uint256) public rewardPools;     // 提案ID => 奖励池金额

    // 统计数据
    VoteStats public voteStats;

    // 用户数据
    mapping(address => uint256[]) public userProposals; // 用户创建的提案列表
    mapping(address => uint256[]) public userVotes;     // 用户投票的提案列表

    // 提案列表
    uint256[] public allProposalIds;

    // ==================== 修饰符 ====================

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        if (proposalId == 0 || proposalId > proposalCount) revert ProposalNotFound();
        _;
    }

    // ==================== 构造函数 ====================

    /**
     * @dev 构造函数
     * @param _ydToken YD代币地址
     * @param _courseContract 课程合约地址
     */
    constructor(address _ydToken, address _courseContract) {
        require(_ydToken != address(0), "Invalid token address");
        require(_courseContract != address(0), "Invalid course contract address");

        ydToken = IERC20(_ydToken);
        courseContract = ICourseContract(_courseContract);
        admin = msg.sender;

        // 初始化默认配置
        daoConfig = DAOConfig({
            proposalDeposit: 1000 * 1e18,        // 1000 YD
            minVotingPower: 100 * 1e18,          // 100 YD
            votingPeriod: 7 days,                // 7天投票期
            quorumPercentage: 1000,              // 10% 法定人数
            passThreshold: 5000,                 // 50% 通过阈值
            rewardPoolPercentage: 8000           // 80% 进入奖励池，20%给平台
        });
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 创建提案
     */
    function createProposal(
        uint256 courseId,
        string memory reason
    ) external override nonReentrant whenNotPaused returns (uint256) {
        // 验证课程存在
        ICourseContract.Course memory course = courseContract.getCourse(courseId);
        if (course.id == 0) revert InvalidCourse();

        // 检查课程是否已有活跃提案
        if (hasActiveProposal[courseId]) revert ProposalAlreadyExists();

        // 检查提案押金
        uint256 userBalance = ydToken.balanceOf(msg.sender);
        if (userBalance < daoConfig.proposalDeposit) revert InsufficientDeposit();

        // 转移押金到合约
        require(
            ydToken.transferFrom(msg.sender, address(this), daoConfig.proposalDeposit),
            "Transfer failed"
        );

        // 创建提案
        proposalCount++;
        uint256 proposalId = proposalCount;

        uint256 votingStartTime = block.timestamp;
        uint256 votingEndTime = block.timestamp + daoConfig.votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            courseId: courseId,
            proposer: msg.sender,
            reason: reason,
            proposalDeposit: daoConfig.proposalDeposit,
            createdAt: block.timestamp,
            votingStartTime: votingStartTime,
            votingEndTime: votingEndTime,
            forVotes: 0,
            againstVotes: 0,
            totalVotingPower: 0,
            status: ProposalStatus.Active,
            executed: false
        });

        // 更新映射
        courseProposals[courseId] = proposalId;
        hasActiveProposal[courseId] = true;
        userProposals[msg.sender].push(proposalId);
        allProposalIds.push(proposalId);

        // 更新统计
        voteStats.totalProposals++;
        voteStats.activeProposals++;

        emit ProposalCreated(
            proposalId,
            courseId,
            msg.sender,
            reason,
            daoConfig.proposalDeposit,
            votingEndTime
        );

        return proposalId;
    }

    /**
     * @dev 投票
     */
    function vote(
        uint256 proposalId,
        VoteOption option,
        uint256 votingPower
    ) external override nonReentrant whenNotPaused proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        // 检查投票状态
        if (proposal.status != ProposalStatus.Active) revert VotingNotActive();
        if (block.timestamp >= proposal.votingEndTime) revert VotingAlreadyEnded();
        if (hasVoted[msg.sender][proposalId]) revert AlreadyVoted();

        // 检查投票权重
        if (votingPower < daoConfig.minVotingPower) revert InsufficientVotingPower();
        uint256 userBalance = ydToken.balanceOf(msg.sender);
        if (userBalance < votingPower) revert InsufficientVotingPower();

        // 锁定代币
        require(
            ydToken.transferFrom(msg.sender, address(this), votingPower),
            "Transfer failed"
        );

        // 记录投票
        voteRecords[msg.sender][proposalId] = VoteRecord({
            voter: msg.sender,
            proposalId: proposalId,
            option: option,
            votingPower: votingPower,
            timestamp: block.timestamp,
            rewardClaimed: false
        });

        hasVoted[msg.sender][proposalId] = true;
        userVotes[msg.sender].push(proposalId);

        // 更新投票计数
        if (option == VoteOption.For) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        proposal.totalVotingPower += votingPower;

        // 更新统计（第一次投票的用户）
        if (userVotes[msg.sender].length == 1) {
            voteStats.totalVoters++;
        }

        emit VoteCasted(proposalId, msg.sender, option, votingPower, block.timestamp);
    }

    /**
     * @dev 结束投票并计算结果
     */
    function finalizeProposal(uint256 proposalId)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // 检查投票是否已结束
        if (block.timestamp < proposal.votingEndTime) revert VotingNotEnded();
        if (proposal.status != ProposalStatus.Active) revert VotingNotActive();

        // 计算结果
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

        // 检查是否达到法定人数（基于课程学生数或总供应量）
        uint256 courseStudentCount = courseContract.getCourseStudentCount(proposal.courseId);
        uint256 quorumRequired = (courseStudentCount * daoConfig.quorumPercentage) / 10000;

        // 如果学生数太少，使用固定值
        if (quorumRequired < daoConfig.minVotingPower) {
            quorumRequired = daoConfig.minVotingPower;
        }

        bool quorumReached = totalVotes >= quorumRequired;
        bool votesPassed = false;

        if (quorumReached && totalVotes > 0) {
            // 计算反对票占比
            uint256 againstPercentage = (proposal.againstVotes * 10000) / totalVotes;
            votesPassed = againstPercentage >= daoConfig.passThreshold;
        }

        // 设置提案状态
        if (quorumReached && votesPassed) {
            proposal.status = ProposalStatus.Succeeded;
            voteStats.succeededProposals++;
        } else {
            proposal.status = ProposalStatus.Failed;
            voteStats.failedProposals++;
        }

        // 计算奖励池
        uint256 rewardPool = _calculateRewardPool(proposalId);
        rewardPools[proposalId] = rewardPool;

        // 更新统计
        voteStats.activeProposals--;
        hasActiveProposal[proposal.courseId] = false;

        emit ProposalFinalized(
            proposalId,
            proposal.status,
            proposal.forVotes,
            proposal.againstVotes,
            rewardPool
        );
    }

    /**
     * @dev 执行提案（下架课程或其他操作）
     */
    function executeProposal(uint256 proposalId)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // 检查提案状态
        if (proposal.status != ProposalStatus.Succeeded) revert ProposalNotSucceeded();
        if (proposal.executed) revert ProposalAlreadyExecuted();

        // 标记为已执行
        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;

        // 这里可以添加执行逻辑，例如：
        // - 将课程标记为"质量问题"
        // - 通知课程合约下架课程
        // - 触发退款流程
        // 注意：需要课程合约提供相应接口

        emit ProposalExecuted(proposalId, proposal.courseId, true);
    }

    /**
     * @dev 领取投票奖励
     */
    function claimReward(uint256 proposalId)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // 检查提案是否已完成
        if (proposal.status != ProposalStatus.Succeeded &&
            proposal.status != ProposalStatus.Failed &&
            proposal.status != ProposalStatus.Executed) {
            revert VotingNotEnded();
        }

        // 检查用户是否投票
        if (!hasVoted[msg.sender][proposalId]) revert NoRewardToClaim();

        VoteRecord storage record = voteRecords[msg.sender][proposalId];
        if (record.rewardClaimed) revert NoRewardToClaim();

        // 计算奖励
        uint256 reward = _calculateUserReward(proposalId, msg.sender);
        if (reward == 0) revert NoRewardToClaim();

        // 标记已领取
        record.rewardClaimed = true;

        // 转账奖励
        require(ydToken.transfer(msg.sender, reward), "Reward transfer failed");

        // 更新统计
        voteStats.totalRewardsDistributed += reward;

        emit RewardClaimed(proposalId, msg.sender, reward);
    }

    /**
     * @dev 取消提案
     */
    function cancelProposal(uint256 proposalId)
        external
        override
        nonReentrant
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // 只有提案人可以取消
        if (msg.sender != proposal.proposer) revert NotProposer();

        // 只能在投票开始后24小时内取消，且无人投票
        if (block.timestamp > proposal.votingStartTime + 1 days) revert CannotCancelNow();
        if (proposal.totalVotingPower > 0) revert CannotCancelNow();
        if (proposal.status != ProposalStatus.Active) revert CannotCancelNow();

        // 更新状态
        proposal.status = ProposalStatus.Canceled;
        hasActiveProposal[proposal.courseId] = false;
        voteStats.activeProposals--;

        // 退还押金
        require(
            ydToken.transfer(proposal.proposer, proposal.proposalDeposit),
            "Refund failed"
        );

        emit ProposalCanceled(proposalId, msg.sender);
    }

    // ==================== 内部函数 ====================

    /**
     * @dev 计算奖励池
     */
    function _calculateRewardPool(uint256 proposalId) internal view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];

        uint256 losingVotes;
        if (proposal.status == ProposalStatus.Succeeded) {
            // 投票通过，支持方（For）失败
            losingVotes = proposal.forVotes;
        } else {
            // 投票失败，反对方（Against）失败
            losingVotes = proposal.againstVotes;
        }

        // 奖励池 = 提案押金 + 失败方的投票代币 * 奖励池百分比
        uint256 poolFromVotes = (losingVotes * daoConfig.rewardPoolPercentage) / 10000;
        return proposal.proposalDeposit + poolFromVotes;
    }

    /**
     * @dev 计算用户奖励
     */
    function _calculateUserReward(uint256 proposalId, address voter)
        internal
        view
        returns (uint256)
    {
        Proposal storage proposal = proposals[proposalId];
        VoteRecord storage record = voteRecords[voter][proposalId];

        // 已领取过
        if (record.rewardClaimed) return 0;

        bool isWinner = false;
        uint256 winningVotes = 0;

        // 判断是否在胜利方
        if (proposal.status == ProposalStatus.Succeeded) {
            // 反对方胜利
            isWinner = (record.option == VoteOption.Against);
            winningVotes = proposal.againstVotes;
        } else if (proposal.status == ProposalStatus.Failed) {
            // 支持方胜利
            isWinner = (record.option == VoteOption.For);
            winningVotes = proposal.forVotes;
        }

        if (!isWinner || winningVotes == 0) {
            // 失败方只能取回本金
            return record.votingPower;
        }

        // 胜利方：本金 + 按投票权重分配奖励池
        uint256 rewardPool = rewardPools[proposalId];
        uint256 userShare = (record.votingPower * rewardPool) / winningVotes;

        return record.votingPower + userShare;
    }

    // ==================== 查询功能 ====================

    function getProposal(uint256 proposalId)
        external
        view
        override
        returns (Proposal memory)
    {
        return proposals[proposalId];
    }

    function getVoteRecord(address voter, uint256 proposalId)
        external
        view
        override
        returns (VoteRecord memory)
    {
        return voteRecords[voter][proposalId];
    }

    function getCourseProposal(uint256 courseId)
        external
        view
        override
        returns (uint256 proposalId, bool hasActive)
    {
        proposalId = courseProposals[courseId];
        hasActive = hasActiveProposal[courseId];
    }

    function calculateReward(address voter, uint256 proposalId)
        external
        view
        override
        returns (uint256)
    {
        return _calculateUserReward(proposalId, voter);
    }

    function getDAOConfig()
        external
        view
        override
        returns (DAOConfig memory)
    {
        return daoConfig;
    }

    function getVoteStats()
        external
        view
        override
        returns (VoteStats memory)
    {
        return voteStats;
    }

    function canVote(address voter, uint256 proposalId)
        external
        view
        override
        proposalExists(proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposals[proposalId];

        // 检查投票是否进行中
        if (proposal.status != ProposalStatus.Active) return false;
        if (block.timestamp >= proposal.votingEndTime) return false;

        // 检查是否已投票
        if (hasVoted[voter][proposalId]) return false;

        // 检查代币余额
        uint256 balance = ydToken.balanceOf(voter);
        if (balance < daoConfig.minVotingPower) return false;

        return true;
    }

    function getAllProposals()
        external
        view
        override
        returns (uint256[] memory)
    {
        return allProposalIds;
    }

    function getActiveProposals()
        external
        view
        override
        returns (uint256[] memory)
    {
        // 统计活跃提案数量
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            if (proposals[allProposalIds[i]].status == ProposalStatus.Active) {
                activeCount++;
            }
        }

        // 构建数组
        uint256[] memory activeProposals = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allProposalIds.length; i++) {
            if (proposals[allProposalIds[i]].status == ProposalStatus.Active) {
                activeProposals[index] = allProposalIds[i];
                index++;
            }
        }

        return activeProposals;
    }

    function getUserProposals(address user)
        external
        view
        override
        returns (uint256[] memory)
    {
        return userProposals[user];
    }

    // ==================== 管理功能 ====================

    function updateDAOConfig(
        uint256 proposalDeposit,
        uint256 minVotingPower,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 passThreshold,
        uint256 rewardPoolPercentage
    ) external override onlyAdmin {
        // 验证参数
        if (quorumPercentage > 10000) revert InvalidConfig();
        if (passThreshold > 10000) revert InvalidConfig();
        if (rewardPoolPercentage > 10000) revert InvalidConfig();
        if (votingPeriod < 1 days || votingPeriod > 30 days) revert InvalidConfig();

        daoConfig = DAOConfig({
            proposalDeposit: proposalDeposit,
            minVotingPower: minVotingPower,
            votingPeriod: votingPeriod,
            quorumPercentage: quorumPercentage,
            passThreshold: passThreshold,
            rewardPoolPercentage: rewardPoolPercentage
        });

        emit DAOConfigUpdated(
            proposalDeposit,
            votingPeriod,
            quorumPercentage,
            passThreshold
        );
    }

    function pause() external override onlyAdmin {
        _pause();
    }

    function unpause() external override onlyAdmin {
        _unpause();
    }

    /**
     * @dev 转移管理员权限
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }

    /**
     * @dev 紧急提取（仅用于合约升级或紧急情况）
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyAdmin {
        require(IERC20(token).transfer(admin, amount), "Transfer failed");
    }
}
