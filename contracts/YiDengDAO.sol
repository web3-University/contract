// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title YiDengDAO
 * @dev 投票合约，持有YD代币的用户可以创建提案和投票
 * @notice 创建提案需要质押YD代币，每个账户投票权重为1票，胜诉方将获得奖励，败诉方不受惩罚
 */
contract YiDengDAO is Ownable {
    // YD代币合约接口
    IERC20 public ydToken;

    /**
     * @dev 提案结构体
     * @param id 提案的唯一标识符（字符串类型）
     * @param timestamp 提案创建的时间戳
     * @param votesFor 赞成票的总票数（每个账户1票）
     * @param votesAgainst 反对票的总票数（每个账户1票）
     * @param executed 提案是否已执行
     * @param hasVoted 记录地址是否已投票的映射
     * @param votedFor 记录地址是否投赞成票的映射
     * @param creator 提案创建者地址
     * @param stakeAmount 创建提案时质押的YD代币数量
     * @param exists 提案是否存在
     */
    struct Proposal {
        string id;
        uint256 timestamp;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedFor;
        address creator;
        uint256 stakeAmount;
        bool exists;
    }

    // 提案ID（字符串）到提案数据的映射
    mapping(string => Proposal) public proposals;

    // 提案ID到投票者地址数组的映射，用于记录所有参与投票的地址
    mapping(string => address[]) public proposalVoters;

    // 所有提案ID的列表
    string[] public proposalIds;

    // 投票持续时间，设置为7天
    uint256 public votingDuration = 7 days;

    // 创建提案所需质押的YD代币数量
    uint256 public stakeAmount;

    /**
     * @dev 提案创建事件
     * @param proposalId 新创建的提案ID
     * @param timestamp 提案创建时间
     * @param creator 提案创建者地址
     * @param stakeAmount 质押的代币数量
     */
    event ProposalCreated(
        string indexed proposalId,
        uint256 timestamp,
        address indexed creator,
        uint256 stakeAmount
    );

    /**
     * @dev 投票事件
     * @param proposalId 提案ID
     * @param voter 投票者地址
     * @param support 是否支持（true为赞成，false为反对）
     */
    event Voted(string indexed proposalId, address indexed voter, bool support);

    /**
     * @dev 提案执行事件
     * @param proposalId 提案ID
     * @param passed 提案是否通过（true为通过，false为未通过）
     */
    event ProposalExecuted(string indexed proposalId, bool passed);

    /**
     * @dev 奖励分发事件
     * @param proposalId 提案ID
     * @param voter 获得奖励的投票者地址
     * @param amount 奖励金额
     */
    event RewardDistributed(
        string indexed proposalId,
        address indexed voter,
        uint256 amount
    );

    /**
     * @dev 质押退还事件
     * @param proposalId 提案ID
     * @param creator 提案创建者地址
     * @param amount 退还的质押金额
     */
    event StakeReturned(
        string indexed proposalId,
        address indexed creator,
        uint256 amount
    );

    /**
     * @dev 构造函数
     * @param _ydToken YD代币合约地址
     * @param _stakeAmount 创建提案所需质押的YD代币数量
     */
    constructor(address _ydToken, uint256 _stakeAmount) Ownable(msg.sender) {
        ydToken = IERC20(_ydToken);
        stakeAmount = _stakeAmount;
    }

    /**
     * @dev 创建新提案
     * @notice 创建提案需要质押指定数量的YD代币到合约
     * @param _proposalId 提案的唯一标识符（字符串）
     */
    function createProposal(string memory _proposalId) external {
        // 检查提案ID是否已存在
        require(!proposals[_proposalId].exists, "Proposal ID already exists");

        // 检查提案ID不能为空
        require(bytes(_proposalId).length > 0, "Proposal ID cannot be empty");

        // 检查调用者的YD代币余额是否足够质押
        require(
            ydToken.balanceOf(msg.sender) >= stakeAmount,
            "Insufficient YD tokens for staking"
        );

        // 从调用者账户转移质押的YD代币到合约
        require(
            ydToken.transferFrom(msg.sender, address(this), stakeAmount),
            "Stake transfer failed"
        );

        // 获取新提案的存储引用
        Proposal storage newProposal = proposals[_proposalId];

        // 初始化提案数据
        newProposal.id = _proposalId;
        newProposal.timestamp = block.timestamp; // 记录创建时间
        newProposal.executed = false; // 初始状态为未执行
        newProposal.creator = msg.sender; // 记录创建者地址
        newProposal.stakeAmount = stakeAmount; // 记录质押金额
        newProposal.exists = true; // 标记提案存在

        // 将提案ID添加到列表
        proposalIds.push(_proposalId);

        // 触发提案创建事件
        emit ProposalCreated(
            _proposalId,
            block.timestamp,
            msg.sender,
            stakeAmount
        );
    }

    /**
     * @dev 对提案进行投票
     * @notice 只有持有YD代币的用户才能投票，每个账户只有1票
     * @param _proposalId 要投票的提案ID
     * @param _support true表示赞成，false表示反对
     */
    function vote(string memory _proposalId, bool _support) external {
        // 检查提案是否存在
        require(proposals[_proposalId].exists, "Proposal does not exist");

        // 获取提案的存储引用
        Proposal storage proposal = proposals[_proposalId];

        // 检查提案是否已执行
        require(!proposal.executed, "Proposal already executed");

        // 检查是否在投票期内（提案创建后7天内）
        require(
            block.timestamp <= proposal.timestamp + votingDuration,
            "Voting period ended"
        );

        // 检查用户是否已经投过票
        require(!proposal.hasVoted[msg.sender], "Already voted");

        // 检查投票者是否持有YD代币
        require(
            ydToken.balanceOf(msg.sender) > 0,
            "Must hold YD tokens to vote"
        );

        // 标记用户已投票
        proposal.hasVoted[msg.sender] = true;

        // 将投票者地址添加到投票者列表中
        proposalVoters[_proposalId].push(msg.sender);

        // 根据投票选择更新票数，每个账户计为1票
        if (_support) {
            // 投赞成票，票数+1
            proposal.votesFor += 1;
            proposal.votedFor[msg.sender] = true;
        } else {
            // 投反对票，票数+1
            proposal.votesAgainst += 1;
        }

        // 触发投票事件
        emit Voted(_proposalId, msg.sender, _support);
    }

    /**
     * @dev 执行提案并自动分发奖励给胜诉方，同时退还质押给提案创建者
     * @notice 只有合约拥有者可以调用此函数
     * @param _proposalId 要执行的提案ID
     * @param _rewardAmount 每个胜诉方投票者获得的奖励金额
     */
    function executeProposalAndDistributeRewards(
        string memory _proposalId,
        uint256 _rewardAmount
    ) external onlyOwner {
        // 检查提案是否存在
        require(proposals[_proposalId].exists, "Proposal does not exist");

        // 获取提案的存储引用
        Proposal storage proposal = proposals[_proposalId];

        // 检查提案是否已执行
        require(!proposal.executed, "Proposal already executed");

        // 检查投票期是否已结束（必须超过7天）
        require(
            block.timestamp > proposal.timestamp + votingDuration,
            "Voting period not ended"
        );

        // 标记提案为已执行
        proposal.executed = true;

        // 判断提案是否通过（赞成票多于反对票）
        bool passed = proposal.votesFor > proposal.votesAgainst;

        // 触发提案执行事件
        emit ProposalExecuted(_proposalId, passed);

        // 退还质押给提案创建者
        require(
            ydToken.transfer(proposal.creator, proposal.stakeAmount),
            "Stake return failed"
        );
        emit StakeReturned(_proposalId, proposal.creator, proposal.stakeAmount);

        // 获取该提案的所有投票者
        address[] memory voters = proposalVoters[_proposalId];

        // 遍历所有投票者，向胜诉方发放奖励
        for (uint256 i = 0; i < voters.length; i++) {
            address voter = voters[i];

            // 判断该投票者是否属于胜诉方
            // 如果提案通过且投了赞成票，或者提案未通过且投了反对票，则为胜诉方
            bool isWinner = (passed && proposal.votedFor[voter]) ||
                (!passed && !proposal.votedFor[voter]);

            // 如果是胜诉方，发放奖励
            if (isWinner) {
                // 从合约向投票者转账YD代币作为奖励
                require(
                    ydToken.transfer(voter, _rewardAmount),
                    "Reward transfer failed"
                );

                // 触发奖励分发事件
                emit RewardDistributed(_proposalId, voter, _rewardAmount);
            }
        }
    }

    /**
     * @dev 获取提案的基本信息
     * @param _proposalId 提案ID
     * @return id 提案ID
     * @return timestamp 提案创建时间
     * @return votesFor 赞成票数
     * @return votesAgainst 反对票数
     * @return executed 是否已执行
     */
    function getProposal(
        string memory _proposalId
    )
        external
        view
        returns (
            string memory id,
            uint256 timestamp,
            uint256 votesFor,
            uint256 votesAgainst,
            bool executed
        )
    {
        // 检查提案是否存在
        require(proposals[_proposalId].exists, "Proposal does not exist");

        // 获取提案的存储引用
        Proposal storage proposal = proposals[_proposalId];

        // 返回提案信息
        return (
            proposal.id,
            proposal.timestamp,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.executed
        );
    }

    /**
     * @dev 检查指定地址是否已对某提案投票
     * @param _proposalId 提案ID
     * @param _voter 要查询的地址
     * @return 如果已投票返回true，否则返回false
     */
    function hasVoted(
        string memory _proposalId,
        address _voter
    ) external view returns (bool) {
        require(proposals[_proposalId].exists, "Proposal does not exist");
        return proposals[_proposalId].hasVoted[_voter];
    }

    /**
     * @dev 获取某提案的所有投票者地址列表
     * @param _proposalId 提案ID
     * @return 投票者地址数组
     */
    function getProposalVoters(
        string memory _proposalId
    ) external view returns (address[] memory) {
        require(proposals[_proposalId].exists, "Proposal does not exist");
        return proposalVoters[_proposalId];
    }

    /**
     * @dev 获取所有提案ID列表
     * @return 提案ID数组
     */
    function getAllProposalIds() external view returns (string[] memory) {
        return proposalIds;
    }

    /**
     * @dev 获取提案总数
     * @return 提案总数
     */
    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    /**
     * @dev 设置创建提案所需的质押金额
     * @notice 只有合约拥有者可以调用
     * @param _stakeAmount 新的质押金额
     */
    function setStakeAmount(uint256 _stakeAmount) external onlyOwner {
        stakeAmount = _stakeAmount;
    }
}
