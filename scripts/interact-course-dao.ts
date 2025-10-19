/**
 * CourseDAO 合约交互脚本
 *
 * 功能说明:
 * - 查看 DAO 配置
 * - 查看提案信息
 * - 查看投票统计
 * - 测试创建提案和投票流程
 *
 * 使用方法:
 * npx hardhat run scripts/interact-course-dao.ts --network localhost
 *
 * 环境变量:
 * - COURSE_DAO_ADDRESS: CourseDAO 合约地址
 */

import { ethers, network } from "hardhat";

// ==================== 配置 ====================

const COURSE_DAO_ADDRESS = process.env.COURSE_DAO_ADDRESS || "";

// ==================== 辅助函数 ====================

function formatTimestamp(timestamp: bigint): string {
  const date = new Date(Number(timestamp) * 1000);
  return date.toLocaleString("zh-CN");
}

function formatDuration(seconds: bigint): string {
  const days = Number(seconds) / 86400;
  return `${days} 天`;
}

function formatPercentage(value: bigint): string {
  return `${Number(value) / 100}%`;
}

// ==================== 查询函数 ====================

async function viewDAOConfig(courseDAO: any) {
  console.log("\n==================== DAO 配置 ====================");

  const config = await courseDAO.getDAOConfig();

  console.log("\n基本配置:");
  console.log("  提案押金:", ethers.formatEther(config.proposalDeposit), "YD");
  console.log("  最小投票权:", ethers.formatEther(config.minVotingPower), "YD");
  console.log("  投票期限:", formatDuration(config.votingPeriod));
  console.log("  法定人数比例:", formatPercentage(config.quorumPercentage));
  console.log("  通过阈值:", formatPercentage(config.passThreshold));
  console.log("  奖励池比例:", formatPercentage(config.rewardPoolPercentage));

  const admin = await courseDAO.admin();
  console.log("\n管理员:", admin);
}

async function viewVoteStats(courseDAO: any) {
  console.log("\n==================== 投票统计 ====================");

  const stats = await courseDAO.getVoteStats();

  console.log("\n提案统计:");
  console.log("  总提案数:", stats.totalProposals.toString());
  console.log("  活跃提案:", stats.activeProposals.toString());
  console.log("  成功提案:", stats.succeededProposals.toString());
  console.log("  失败提案:", stats.failedProposals.toString());

  console.log("\n参与统计:");
  console.log("  总投票人数:", stats.totalVoters.toString());
  console.log("  总奖励分配:", ethers.formatEther(stats.totalRewardsDistributed), "YD");
}

async function viewProposal(courseDAO: any, proposalId: number) {
  console.log(`\n==================== 提案 #${proposalId} ====================`);

  try {
    const proposal = await courseDAO.getProposal(proposalId);

    if (proposal.id === 0n) {
      console.log("提案不存在");
      return;
    }

    const statusNames = ["Active", "Succeeded", "Failed", "Canceled", "Executed"];

    console.log("\n基本信息:");
    console.log("  提案 ID:", proposal.id.toString());
    console.log("  课程 ID:", proposal.courseId.toString());
    console.log("  提案人:", proposal.proposer);
    console.log("  理由:", proposal.reason);
    console.log("  状态:", statusNames[proposal.status]);
    console.log("  已执行:", proposal.executed ? "是" : "否");

    console.log("\n时间信息:");
    console.log("  创建时间:", formatTimestamp(proposal.createdAt));
    console.log("  投票开始:", formatTimestamp(proposal.votingStartTime));
    console.log("  投票结束:", formatTimestamp(proposal.votingEndTime));

    console.log("\n投票情况:");
    console.log("  支持票:", ethers.formatEther(proposal.forVotes), "YD");
    console.log("  反对票:", ethers.formatEther(proposal.againstVotes), "YD");
    console.log("  总投票权:", ethers.formatEther(proposal.totalVotingPower), "YD");

    const totalVotes = proposal.forVotes + proposal.againstVotes;
    if (totalVotes > 0n) {
      const forPercentage = (Number(proposal.forVotes) * 100) / Number(totalVotes);
      const againstPercentage = (Number(proposal.againstVotes) * 100) / Number(totalVotes);
      console.log("  支持比例:", forPercentage.toFixed(2), "%");
      console.log("  反对比例:", againstPercentage.toFixed(2), "%");
    }

    console.log("\n押金信息:");
    console.log("  押金金额:", ethers.formatEther(proposal.proposalDeposit), "YD");

    // 查看奖励池
    const rewardPool = await courseDAO.rewardPools(proposalId);
    if (rewardPool > 0n) {
      console.log("\n奖励池:", ethers.formatEther(rewardPool), "YD");
    }
  } catch (error: any) {
    console.log("查询失败:", error.message);
  }
}

async function viewAllProposals(courseDAO: any) {
  console.log("\n==================== 所有提案 ====================");

  const proposalIds = await courseDAO.getAllProposals();

  if (proposalIds.length === 0) {
    console.log("暂无提案");
    return;
  }

  const statusNames = ["Active", "Succeeded", "Failed", "Canceled", "Executed"];

  console.log(`\n共有 ${proposalIds.length} 个提案:\n`);

  for (const id of proposalIds) {
    const proposal = await courseDAO.getProposal(id);
    console.log(`提案 #${id}:`);
    console.log(`  课程 ID: ${proposal.courseId}`);
    console.log(`  状态: ${statusNames[proposal.status]}`);
    console.log(`  理由: ${proposal.reason.substring(0, 50)}${proposal.reason.length > 50 ? "..." : ""}`);
    console.log(`  投票: 支持 ${ethers.formatEther(proposal.forVotes)} YD, 反对 ${ethers.formatEther(proposal.againstVotes)} YD`);
    console.log();
  }
}

async function viewUserInfo(courseDAO: any, userAddress: string) {
  console.log(`\n==================== 用户信息: ${userAddress} ====================`);

  const userProposals = await courseDAO.getUserProposals(userAddress);
  console.log(`\n创建的提案数: ${userProposals.length}`);
  if (userProposals.length > 0) {
    console.log("提案 IDs:", userProposals.map((id: any) => id.toString()).join(", "));
  }

  // 注意: getUserVotes 在原合约中没有实现，这里注释掉
  // const userVotes = await courseDAO.getUserVotes(userAddress);
  // console.log(`\n参与投票数: ${userVotes.length}`);
}

// ==================== 测试函数 ====================

async function testCreateProposal(
  courseDAO: any,
  ydToken: any,
  courseId: number,
  reason: string
) {
  console.log("\n==================== 测试创建提案 ====================");

  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  // 检查余额
  const balance = await ydToken.balanceOf(signerAddress);
  console.log("当前余额:", ethers.formatEther(balance), "YD");

  const config = await courseDAO.getDAOConfig();
  console.log("需要押金:", ethers.formatEther(config.proposalDeposit), "YD");

  if (balance < config.proposalDeposit) {
    console.log("⚠ 余额不足，无法创建提案");
    return;
  }

  // 检查授权
  const courseDaoAddress = await courseDAO.getAddress();
  const allowance = await ydToken.allowance(signerAddress, courseDaoAddress);
  console.log("当前授权:", ethers.formatEther(allowance), "YD");

  if (allowance < config.proposalDeposit) {
    console.log("\n批准 CourseDAO 使用代币...");
    const approveTx = await ydToken.approve(courseDaoAddress, config.proposalDeposit);
    await approveTx.wait();
    console.log("✓ 授权成功");
  }

  // 创建提案
  console.log(`\n创建提案 (课程 ID: ${courseId})...`);
  const tx = await courseDAO.createProposal(courseId, reason);
  const receipt = await tx.wait();

  console.log("✓ 提案创建成功");
  console.log("交易哈希:", receipt.hash);

  // 从事件中获取提案 ID
  const proposalCreatedEvent = receipt.logs.find(
    (log: any) => log.fragment && log.fragment.name === "ProposalCreated"
  );

  if (proposalCreatedEvent) {
    const proposalId = proposalCreatedEvent.args[0];
    console.log("提案 ID:", proposalId.toString());
    return proposalId;
  }
}

async function testVote(
  courseDAO: any,
  ydToken: any,
  proposalId: number,
  voteOption: number,
  votingPower: bigint
) {
  console.log("\n==================== 测试投票 ====================");

  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  // 检查是否可以投票
  const canVote = await courseDAO.canVote(signerAddress, proposalId);
  if (!canVote) {
    console.log("⚠ 无法投票 (可能已投票或提案已结束)");
    return;
  }

  // 检查余额
  const balance = await ydToken.balanceOf(signerAddress);
  console.log("当前余额:", ethers.formatEther(balance), "YD");
  console.log("投票权重:", ethers.formatEther(votingPower), "YD");

  if (balance < votingPower) {
    console.log("⚠ 余额不足");
    return;
  }

  // 检查授权
  const courseDaoAddress = await courseDAO.getAddress();
  const allowance = await ydToken.allowance(signerAddress, courseDaoAddress);

  if (allowance < votingPower) {
    console.log("\n批准 CourseDAO 使用代币...");
    const approveTx = await ydToken.approve(courseDaoAddress, votingPower);
    await approveTx.wait();
    console.log("✓ 授权成功");
  }

  // 投票
  const voteOptionName = voteOption === 0 ? "支持" : "反对";
  console.log(`\n投 ${voteOptionName} 票...`);

  const tx = await courseDAO.vote(proposalId, voteOption, votingPower);
  const receipt = await tx.wait();

  console.log("✓ 投票成功");
  console.log("交易哈希:", receipt.hash);
}

// ==================== 主函数 ====================

async function main() {
  console.log("\n==================== CourseDAO 交互脚本 ====================");
  console.log("网络:", network.name);

  if (!COURSE_DAO_ADDRESS) {
    console.log("\n⚠ 请设置环境变量 COURSE_DAO_ADDRESS");
    return;
  }

  // 获取合约实例
  const courseDAO = await ethers.getContractAt("CourseDAO", COURSE_DAO_ADDRESS);
  console.log("CourseDAO 地址:", COURSE_DAO_ADDRESS);

  // 获取依赖合约
  const ydTokenAddress = await courseDAO.ydToken();
  const ydToken = await ethers.getContractAt("IERC20", ydTokenAddress);
  console.log("YD Token 地址:", ydTokenAddress);

  // 查看配置
  await viewDAOConfig(courseDAO);

  // 查看统计
  await viewVoteStats(courseDAO);

  // 查看所有提案
  await viewAllProposals(courseDAO);

  // 如果你想测试创建提案和投票，取消下面的注释:

  /*
  // 测试创建提案
  const courseId = 1;
  const reason = "课程质量不符合标准，需要下架处理";
  const proposalId = await testCreateProposal(courseDAO, ydToken, courseId, reason);

  if (proposalId) {
    // 查看新创建的提案
    await viewProposal(courseDAO, Number(proposalId));

    // 测试投票
    const voteOption = 1; // 0 = For (支持), 1 = Against (反对)
    const votingPower = ethers.parseEther("500");
    await testVote(courseDAO, ydToken, Number(proposalId), voteOption, votingPower);

    // 再次查看提案（包含投票结果）
    await viewProposal(courseDAO, Number(proposalId));
  }
  */

  console.log("\n==================== 交互完成 ====================\n");
}

// ==================== 执行脚本 ====================

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n执行失败:");
    console.error(error);
    process.exit(1);
  });
