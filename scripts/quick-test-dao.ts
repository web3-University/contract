/**
 * CourseDAO 快速测试脚本
 *
 * 功能说明:
 * - 部署所有合约
 * - 创建测试课程
 * - 分配代币给测试账户
 * - 创建提案
 * - 多个账户投票
 * - 结束投票并查看结果
 * - 领取奖励
 *
 * 使用方法:
 * npx hardhat run scripts/quick-test-dao.ts --network localhost
 */

import { ethers } from "hardhat";

async function main() {
  console.log("\n==================== CourseDAO 快速测试 ====================\n");

  const [deployer, user1, user2, user3] = await ethers.getSigners();

  console.log("测试账户:");
  console.log("  Deployer:", deployer.address);
  console.log("  User1:", user1.address);
  console.log("  User2:", user2.address);
  console.log("  User3:", user3.address);

  // ==================== 步骤 1: 部署合约 ====================

  console.log("\n==================== 步骤 1: 部署合约 ====================");

  // 部署 YD Token
  console.log("\n部署 YD Token...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const ydToken = await MockERC20.deploy("YD Token", "YD", ethers.parseEther("1000000"));
  await ydToken.waitForDeployment();
  const ydTokenAddress = await ydToken.getAddress();
  console.log("✓ YD Token:", ydTokenAddress);

  // 部署 Course Contract
  console.log("\n部署 Course Contract...");
  const MockCourseContract = await ethers.getContractFactory("MockCourseContract");
  const courseContract = await MockCourseContract.deploy();
  await courseContract.waitForDeployment();
  const courseContractAddress = await courseContract.getAddress();
  console.log("✓ Course Contract:", courseContractAddress);

  // 部署 CourseDAO
  console.log("\n部署 CourseDAO...");
  const CourseDAO = await ethers.getContractFactory("CourseDAO");
  const courseDAO = await CourseDAO.deploy(ydTokenAddress, courseContractAddress);
  await courseDAO.waitForDeployment();
  const courseDaoAddress = await courseDAO.getAddress();
  console.log("✓ CourseDAO:", courseDaoAddress);

  // ==================== 步骤 2: 创建测试课程 ====================

  console.log("\n==================== 步骤 2: 创建测试课程 ====================");

  const tx1 = await courseContract.createMockCourse(
    "区块链开发入门",
    "学习智能合约开发",
    deployer.address,
    ethers.parseEther("0.1")
  );
  await tx1.wait();

  const courseId = 1;
  console.log("✓ 创建课程 ID:", courseId);

  // 设置课程学生数
  await courseContract.setStudentCount(courseId, 100);
  console.log("✓ 设置课程学生数: 100");

  // ==================== 步骤 3: 分配代币 ====================

  console.log("\n==================== 步骤 3: 分配代币给用户 ====================");

  const distributions = [
    { user: user1, amount: ethers.parseEther("5000") },
    { user: user2, amount: ethers.parseEther("3000") },
    { user: user3, amount: ethers.parseEther("2000") },
  ];

  for (const { user, amount } of distributions) {
    await ydToken.transfer(user.address, amount);
    const balance = await ydToken.balanceOf(user.address);
    console.log(`✓ ${user.address} 余额:`, ethers.formatEther(balance), "YD");
  }

  // ==================== 步骤 4: 创建提案 ====================

  console.log("\n==================== 步骤 4: 创建提案 ====================");

  const config = await courseDAO.getDAOConfig();
  console.log("提案押金:", ethers.formatEther(config.proposalDeposit), "YD");

  // User1 创建提案
  const user1DAO = courseDAO.connect(user1);
  const user1Token = ydToken.connect(user1);

  console.log("\nUser1 授权并创建提案...");
  await user1Token.approve(courseDaoAddress, config.proposalDeposit);

  const reason = "课程内容质量不符合标准，讲解不清晰，需要下架处理";
  const tx2 = await user1DAO.createProposal(courseId, reason);
  const receipt = await tx2.wait();

  const proposalId = 1;
  console.log("✓ 提案创建成功, ID:", proposalId);

  // 查看提案
  const proposal = await courseDAO.getProposal(proposalId);
  console.log("\n提案信息:");
  console.log("  提案人:", proposal.proposer);
  console.log("  课程 ID:", proposal.courseId.toString());
  console.log("  理由:", proposal.reason);
  console.log("  投票截止:", new Date(Number(proposal.votingEndTime) * 1000).toLocaleString("zh-CN"));

  // ==================== 步骤 5: 投票 ====================

  console.log("\n==================== 步骤 5: 多账户投票 ====================");

  // User1 投反对票
  console.log("\nUser1 投反对票...");
  const user1VotePower = ethers.parseEther("1000");
  await user1Token.approve(courseDaoAddress, user1VotePower);
  await user1DAO.vote(proposalId, 1, user1VotePower); // 1 = Against
  console.log("✓ User1 投票:", ethers.formatEther(user1VotePower), "YD (反对)");

  // User2 投反对票
  console.log("\nUser2 投反对票...");
  const user2DAO = courseDAO.connect(user2);
  const user2Token = ydToken.connect(user2);
  const user2VotePower = ethers.parseEther("800");
  await user2Token.approve(courseDaoAddress, user2VotePower);
  await user2DAO.vote(proposalId, 1, user2VotePower); // 1 = Against
  console.log("✓ User2 投票:", ethers.formatEther(user2VotePower), "YD (反对)");

  // User3 投支持票
  console.log("\nUser3 投支持票...");
  const user3DAO = courseDAO.connect(user3);
  const user3Token = ydToken.connect(user3);
  const user3VotePower = ethers.parseEther("500");
  await user3Token.approve(courseDaoAddress, user3VotePower);
  await user3DAO.vote(proposalId, 0, user3VotePower); // 0 = For
  console.log("✓ User3 投票:", ethers.formatEther(user3VotePower), "YD (支持)");

  // 查看投票结果
  const proposalAfterVote = await courseDAO.getProposal(proposalId);
  console.log("\n当前投票情况:");
  console.log("  支持票:", ethers.formatEther(proposalAfterVote.forVotes), "YD");
  console.log("  反对票:", ethers.formatEther(proposalAfterVote.againstVotes), "YD");
  console.log("  总投票权:", ethers.formatEther(proposalAfterVote.totalVotingPower), "YD");

  const totalVotes = proposalAfterVote.forVotes + proposalAfterVote.againstVotes;
  const againstPercentage = (Number(proposalAfterVote.againstVotes) * 100) / Number(totalVotes);
  console.log("  反对票占比:", againstPercentage.toFixed(2), "%");

  // ==================== 步骤 6: 快进时间并结束投票 ====================

  console.log("\n==================== 步骤 6: 结束投票 ====================");

  console.log("\n快进时间 7 天...");
  await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
  await ethers.provider.send("evm_mine", []);

  console.log("结束投票...");
  const tx3 = await courseDAO.finalizeProposal(proposalId);
  await tx3.wait();
  console.log("✓ 投票已结束");

  // 查看最终结果
  const finalProposal = await courseDAO.getProposal(proposalId);
  const statusNames = ["Active", "Succeeded", "Failed", "Canceled", "Executed"];
  console.log("\n最终结果:");
  console.log("  状态:", statusNames[finalProposal.status]);
  console.log("  支持票:", ethers.formatEther(finalProposal.forVotes), "YD");
  console.log("  反对票:", ethers.formatEther(finalProposal.againstVotes), "YD");

  const rewardPool = await courseDAO.rewardPools(proposalId);
  console.log("  奖励池:", ethers.formatEther(rewardPool), "YD");

  // ==================== 步骤 7: 领取奖励 ====================

  console.log("\n==================== 步骤 7: 领取奖励 ====================");

  // User1 领取奖励
  console.log("\nUser1 领取奖励...");
  const user1RewardBefore = await ydToken.balanceOf(user1.address);
  const user1ExpectedReward = await courseDAO.calculateReward(user1.address, proposalId);
  console.log("预期奖励:", ethers.formatEther(user1ExpectedReward), "YD");

  await user1DAO.claimReward(proposalId);
  const user1RewardAfter = await ydToken.balanceOf(user1.address);
  const user1ActualReward = user1RewardAfter - user1RewardBefore;
  console.log("✓ 实际获得:", ethers.formatEther(user1ActualReward), "YD");

  // User2 领取奖励
  console.log("\nUser2 领取奖励...");
  const user2RewardBefore = await ydToken.balanceOf(user2.address);
  const user2ExpectedReward = await courseDAO.calculateReward(user2.address, proposalId);
  console.log("预期奖励:", ethers.formatEther(user2ExpectedReward), "YD");

  await user2DAO.claimReward(proposalId);
  const user2RewardAfter = await ydToken.balanceOf(user2.address);
  const user2ActualReward = user2RewardAfter - user2RewardBefore;
  console.log("✓ 实际获得:", ethers.formatEther(user2ActualReward), "YD");

  // User3 领取本金
  console.log("\nUser3 领取本金...");
  const user3RewardBefore = await ydToken.balanceOf(user3.address);
  const user3ExpectedReward = await courseDAO.calculateReward(user3.address, proposalId);
  console.log("预期返还:", ethers.formatEther(user3ExpectedReward), "YD");

  await user3DAO.claimReward(proposalId);
  const user3RewardAfter = await ydToken.balanceOf(user3.address);
  const user3ActualReward = user3RewardAfter - user3RewardBefore;
  console.log("✓ 实际获得:", ethers.formatEther(user3ActualReward), "YD");

  // ==================== 步骤 8: 查看统计 ====================

  console.log("\n==================== 步骤 8: 查看统计数据 ====================");

  const stats = await courseDAO.getVoteStats();
  console.log("\nDAO 统计:");
  console.log("  总提案数:", stats.totalProposals.toString());
  console.log("  活跃提案:", stats.activeProposals.toString());
  console.log("  成功提案:", stats.succeededProposals.toString());
  console.log("  失败提案:", stats.failedProposals.toString());
  console.log("  总投票人数:", stats.totalVoters.toString());
  console.log("  总奖励分配:", ethers.formatEther(stats.totalRewardsDistributed), "YD");

  console.log("\n用户最终余额:");
  console.log("  User1:", ethers.formatEther(await ydToken.balanceOf(user1.address)), "YD");
  console.log("  User2:", ethers.formatEther(await ydToken.balanceOf(user2.address)), "YD");
  console.log("  User3:", ethers.formatEther(await ydToken.balanceOf(user3.address)), "YD");

  console.log("\n==================== 测试完成 ====================\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n测试失败:");
    console.error(error);
    process.exit(1);
  });
