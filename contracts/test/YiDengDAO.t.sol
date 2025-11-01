// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {YiDengDAO} from "../YiDengDAO.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

// 模拟YD代币合约（用于测试）
contract MockYDToken is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    function mint(address to, uint256 amount) public {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(
            _allowances[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
}

contract YiDengDAOTest is Test {
    YiDengDAO dao;
    MockYDToken token;
    address owner;
    address user1;
    address user2;
    address user3;

    uint256 constant STAKE_AMOUNT = 100 * 10 ** 18; // 创建提案需要质押100个YD代币
    uint256 constant REWARD_AMOUNT = 50 * 10 ** 18; // 每个获胜者奖励50个YD代币

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // 部署模拟的YD代币
        token = new MockYDToken();

        // 部署DAO合约
        dao = new YiDengDAO(address(token), STAKE_AMOUNT);

        // 给用户分配YD代币
        token.mint(user1, 1000 * 10 ** 18);
        token.mint(user2, 1000 * 10 ** 18);
        token.mint(user3, 1000 * 10 ** 18);

        // 给合约分配YD代币用于奖励池
        token.mint(address(dao), 10000 * 10 ** 18);
    }

    // 测试合约初始化
    function test_InitialSetup() public view {
        require(
            address(dao.ydToken()) == address(token),
            "YD token address should be correct"
        );
        require(
            dao.stakeAmount() == STAKE_AMOUNT,
            "Stake amount should be correct"
        );
        require(
            dao.votingDuration() == 7 days,
            "Voting duration should be 7 days"
        );
        require(
            dao.getProposalCount() == 0,
            "Initial proposal count should be 0"
        );
    }

    // 测试创建提案
    function test_CreateProposal() public {
        string memory proposalId = "PROP-001";

        // 用户1授权DAO合约使用代币
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);

        // 用户1创建提案
        vm.prank(user1);
        dao.createProposal(proposalId);

        require(dao.getProposalCount() == 1, "Proposal count should be 1");

        // 验证提案信息
        (
            string memory id,
            uint256 timestamp,
            uint256 votesFor,
            uint256 votesAgainst,
            bool executed
        ) = dao.getProposal(proposalId);
        require(
            keccak256(abi.encodePacked(id)) ==
                keccak256(abi.encodePacked(proposalId)),
            "Proposal ID should match"
        );
        require(
            timestamp == block.timestamp,
            "Timestamp should be current block time"
        );
        require(votesFor == 0, "Initial votes for should be 0");
        require(votesAgainst == 0, "Initial votes against should be 0");
        require(!executed, "Proposal should not be executed");
    }

    // 测试创建重复ID的提案
    function test_CreateDuplicateProposal() public {
        string memory proposalId = "PROP-001";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT * 2);

        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user1);
        vm.expectRevert("Proposal ID already exists");
        dao.createProposal(proposalId);
    }

    // 测试创建空ID的提案
    function test_CreateProposalWithEmptyId() public {
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);

        vm.prank(user1);
        vm.expectRevert("Proposal ID cannot be empty");
        dao.createProposal("");
    }

    // 测试创建提案但余额不足
    function test_CreateProposalInsufficientBalance() public {
        address poorUser = address(0x999);
        token.mint(poorUser, 50 * 10 ** 18); // 只给50个代币，不够质押

        vm.prank(poorUser);
        token.approve(address(dao), STAKE_AMOUNT);

        vm.prank(poorUser);
        vm.expectRevert("Insufficient YD tokens for staking");
        dao.createProposal("PROP-001");
    }

    // 测试创建提案但未授权
    function test_CreateProposalWithoutApproval() public {
        vm.prank(user1);
        vm.expectRevert();
        dao.createProposal("PROP-001");
    }

    // 测试投票
    function test_Vote() public {
        string memory proposalId = "PROP-001";

        // 创建提案
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        // 用户2投赞成票
        vm.prank(user2);
        dao.vote(proposalId, true);

        // 验证投票结果
        (, , uint256 votesFor, uint256 votesAgainst, ) = dao.getProposal(
            proposalId
        );
        require(votesFor == 1, "Votes for should be 1");
        require(votesAgainst == 0, "Votes against should be 0");
        require(dao.hasVoted(proposalId, user2), "User2 should have voted");
    }

    // 测试多人投票
    function test_MultipleVotes() public {
        string memory proposalId = "PROP-002";

        // 创建提案
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        // 用户1投赞成票
        vm.prank(user1);
        dao.vote(proposalId, true);

        // 用户2投反对票
        vm.prank(user2);
        dao.vote(proposalId, false);

        // 用户3投赞成票
        vm.prank(user3);
        dao.vote(proposalId, true);

        // 验证投票结果
        (, , uint256 votesFor, uint256 votesAgainst, ) = dao.getProposal(
            proposalId
        );
        require(votesFor == 2, "Votes for should be 2");
        require(votesAgainst == 1, "Votes against should be 1");
    }

    // 测试对不存在的提案投票
    function test_VoteNonExistentProposal() public {
        vm.prank(user1);
        vm.expectRevert("Proposal does not exist");
        dao.vote("NONEXISTENT", true);
    }

    // 测试重复投票失败
    function test_VoteTwice() public {
        string memory proposalId = "PROP-003";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user2);
        dao.vote(proposalId, true);

        vm.prank(user2);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, true);
    }

    // 测试无YD代币用户投票失败
    function test_VoteWithoutTokens() public {
        string memory proposalId = "PROP-004";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        address noTokenUser = address(0x888);
        vm.prank(noTokenUser);
        vm.expectRevert("Must hold YD tokens to vote");
        dao.vote(proposalId, true);
    }

    // 测试投票期结束后投票失败
    function test_VoteAfterPeriodEnded() public {
        string memory proposalId = "PROP-005";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        // 快进8天
        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        vm.expectRevert("Voting period ended");
        dao.vote(proposalId, true);
    }

    // 测试执行提案并分发奖励（提案通过）
    function test_ExecuteProposalAndDistributeRewards_Passed() public {
        string memory proposalId = "PROP-006";

        // 创建提案
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        // 投票：2票赞成，1票反对
        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, true);
        vm.prank(user3);
        dao.vote(proposalId, false);

        // 记录投票前余额
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 user3BalanceBefore = token.balanceOf(user3);

        // 快进8天
        vm.warp(block.timestamp + 8 days);

        // 执行提案
        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);

        // 验证提案已执行
        (, , , , bool executed) = dao.getProposal(proposalId);
        require(executed, "Proposal should be executed");

        // 验证质押退还给创建者（user1）
        require(
            token.balanceOf(user1) ==
                user1BalanceBefore + STAKE_AMOUNT + REWARD_AMOUNT,
            "User1 should receive stake return and reward"
        );

        // 验证赞成方获得奖励（user2）
        require(
            token.balanceOf(user2) == user2BalanceBefore + REWARD_AMOUNT,
            "User2 should receive reward"
        );

        // 验证反对方没有获得奖励（user3）
        require(
            token.balanceOf(user3) == user3BalanceBefore,
            "User3 should not receive reward"
        );
    }

    // 测试执行提案并分发奖励（提案未通过）
    function test_ExecuteProposalAndDistributeRewards_Failed() public {
        string memory proposalId = "PROP-007";

        // 创建提案
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        // 投票：1票赞成，2票反对
        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, false);
        vm.prank(user3);
        dao.vote(proposalId, false);

        // 记录投票前余额
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 user3BalanceBefore = token.balanceOf(user3);

        // 快进8天
        vm.warp(block.timestamp + 8 days);

        // 执行提案
        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);

        // 验证提案已执行
        (, , , , bool executed) = dao.getProposal(proposalId);
        require(executed, "Proposal should be executed");

        // 验证质押退还给创建者（user1），但不获得奖励
        require(
            token.balanceOf(user1) == user1BalanceBefore + STAKE_AMOUNT,
            "User1 should only receive stake return"
        );

        // 验证反对方获得奖励（user2, user3）
        require(
            token.balanceOf(user2) == user2BalanceBefore + REWARD_AMOUNT,
            "User2 should receive reward"
        );
        require(
            token.balanceOf(user3) == user3BalanceBefore + REWARD_AMOUNT,
            "User3 should receive reward"
        );
    }

    // 测试执行不存在的提案
    function test_ExecuteNonExistentProposal() public {
        vm.expectRevert("Proposal does not exist");
        dao.executeProposalAndDistributeRewards("NONEXISTENT", REWARD_AMOUNT);
    }

    // 测试投票期未结束时执行提案失败
    function test_ExecuteProposalBeforePeriodEnded() public {
        string memory proposalId = "PROP-008";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user2);
        dao.vote(proposalId, true);

        vm.expectRevert("Voting period not ended");
        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);
    }

    // 测试重复执行提案失败
    function test_ExecuteProposalTwice() public {
        string memory proposalId = "PROP-009";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user2);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);

        vm.expectRevert("Proposal already executed");
        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);
    }

    // 测试非owner执行提案失败
    function test_ExecuteProposalByNonOwner() public {
        string memory proposalId = "PROP-010";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        vm.expectRevert();
        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);
    }

    // 测试获取投票者列表
    function test_GetProposalVoters() public {
        string memory proposalId = "PROP-011";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user1);
        dao.vote(proposalId, true);
        vm.prank(user2);
        dao.vote(proposalId, false);

        address[] memory voters = dao.getProposalVoters(proposalId);
        require(voters.length == 2, "Should have 2 voters");
        require(voters[0] == user1, "First voter should be user1");
        require(voters[1] == user2, "Second voter should be user2");
    }

    // 测试获取所有提案ID列表
    function test_GetAllProposalIds() public {
        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT * 3);

        vm.prank(user1);
        dao.createProposal("PROP-001");
        vm.prank(user1);
        dao.createProposal("PROP-002");
        vm.prank(user1);
        dao.createProposal("PROP-003");

        string[] memory ids = dao.getAllProposalIds();
        require(ids.length == 3, "Should have 3 proposals");
        require(
            keccak256(abi.encodePacked(ids[0])) ==
                keccak256(abi.encodePacked("PROP-001")),
            "First proposal ID should be PROP-001"
        );
        require(
            keccak256(abi.encodePacked(ids[1])) ==
                keccak256(abi.encodePacked("PROP-002")),
            "Second proposal ID should be PROP-002"
        );
        require(
            keccak256(abi.encodePacked(ids[2])) ==
                keccak256(abi.encodePacked("PROP-003")),
            "Third proposal ID should be PROP-003"
        );
    }

    // 测试设置质押金额（仅owner）
    function test_SetStakeAmount() public {
        uint256 newStakeAmount = 200 * 10 ** 18;
        dao.setStakeAmount(newStakeAmount);
        require(
            dao.stakeAmount() == newStakeAmount,
            "Stake amount should be updated"
        );
    }

    // 测试非owner设置质押金额失败
    function test_SetStakeAmountByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        dao.setStakeAmount(200 * 10 ** 18);
    }

    // 测试事件触发：ProposalCreated
    function test_ProposalCreatedEvent() public {
        string memory proposalId = "PROP-EVENT-001";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit YiDengDAO.ProposalCreated(
            proposalId,
            block.timestamp,
            user1,
            STAKE_AMOUNT
        );

        vm.prank(user1);
        dao.createProposal(proposalId);
    }

    // 测试事件触发：Voted
    function test_VotedEvent() public {
        string memory proposalId = "PROP-EVENT-002";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.expectEmit(true, true, false, true);
        emit YiDengDAO.Voted(proposalId, user2, true);

        vm.prank(user2);
        dao.vote(proposalId, true);
    }

    // 测试事件触发：ProposalExecuted
    function test_ProposalExecutedEvent() public {
        string memory proposalId = "PROP-EVENT-003";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user2);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        vm.expectEmit(true, false, false, true);
        emit YiDengDAO.ProposalExecuted(proposalId, true);

        dao.executeProposalAndDistributeRewards(proposalId, REWARD_AMOUNT);
    }

    // Fuzz测试：使用不同的提案ID
    function testFuzz_CreateProposalWithDifferentIds(
        string memory proposalId
    ) public {
        // 确保ID不为空
        vm.assume(bytes(proposalId).length > 0);
        vm.assume(bytes(proposalId).length < 100); // 限制长度避免gas过高

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);

        vm.prank(user1);
        dao.createProposal(proposalId);

        require(dao.getProposalCount() == 1, "Proposal should be created");

        (string memory id, , , , ) = dao.getProposal(proposalId);
        require(
            keccak256(abi.encodePacked(id)) ==
                keccak256(abi.encodePacked(proposalId)),
            "Proposal ID should match"
        );
    }

    // Fuzz测试：随机奖励金额
    function testFuzz_ExecuteWithDifferentRewardAmounts(
        uint256 rewardAmount
    ) public {
        rewardAmount = bound(rewardAmount, 1 * 10 ** 18, 100 * 10 ** 18);

        string memory proposalId = "PROP-FUZZ-001";

        vm.prank(user1);
        token.approve(address(dao), STAKE_AMOUNT);
        vm.prank(user1);
        dao.createProposal(proposalId);

        vm.prank(user2);
        dao.vote(proposalId, true);

        uint256 balanceBefore = token.balanceOf(user2);

        vm.warp(block.timestamp + 8 days);
        dao.executeProposalAndDistributeRewards(proposalId, rewardAmount);

        require(
            token.balanceOf(user2) == balanceBefore + rewardAmount,
            "User should receive correct reward"
        );
    }
}
