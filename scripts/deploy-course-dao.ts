/**
 * CourseDAO 合约部署脚本
 *
 * 功能说明:
 * - 部署 CourseDAO 投票治理合约
 * - 配置初始参数
 * - 可选择验证合约
 *
 * 使用方法:
 * npx hardhat run scripts/deploy-course-dao.ts --network localhost
 * npx hardhat run scripts/deploy-course-dao.ts --network sepolia
 *
 * 环境变量:
 * - YD_TOKEN_ADDRESS: YD代币合约地址
 * - COURSE_CONTRACT_ADDRESS: 课程合约地址
 * - VERIFY: 是否验证合约 (true/false)
 */

import { ethers, run, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";

// ==================== 配置 ====================

interface DeploymentConfig {
  verify: boolean;
  waitConfirmations: number;
}

interface NetworkAddresses {
  ydToken?: string;
  courseContract?: string;
}

// 网络地址配置 (如果环境变量未设置则使用这些默认值)
const NETWORK_ADDRESSES: Record<string, NetworkAddresses> = {
  localhost: {
    // 本地测试网地址 - 需要先部署这些合约
    ydToken: process.env.YD_TOKEN_ADDRESS || "",
    courseContract: process.env.COURSE_CONTRACT_ADDRESS || "",
  },
  sepolia: {
    // Sepolia 测试网地址
    ydToken: process.env.YD_TOKEN_ADDRESS || "",
    courseContract: process.env.COURSE_CONTRACT_ADDRESS || "",
  },
  hardhat: {
    // Hardhat 网络 - 会在部署时自动部署依赖合约
    ydToken: "",
    courseContract: "",
  },
};

// 部署配置
const DEPLOYMENT_CONFIG: DeploymentConfig = {
  verify: process.env.VERIFY === "true",
  waitConfirmations: network.name === "localhost" || network.name === "hardhat" ? 1 : 5,
};

// ==================== 辅助函数 ====================

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function verifyContract(
  address: string,
  constructorArguments: any[]
): Promise<void> {
  console.log("\n开始验证合约...");
  console.log("合约地址:", address);

  try {
    await run("verify:verify", {
      address: address,
      constructorArguments: constructorArguments,
    });
    console.log("✓ 合约验证成功");
  } catch (error: any) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("✓ 合约已经验证过了");
    } else {
      console.log("✗ 合约验证失败:", error.message);
    }
  }
}

function saveDeploymentInfo(info: any): void {
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filename = `course-dao-${network.name}-${Date.now()}.json`;
  const filepath = path.join(deploymentsDir, filename);

  fs.writeFileSync(filepath, JSON.stringify(info, null, 2));
  console.log("\n部署信息已保存至:", filepath);
}

// ==================== 部署 Mock 合约 (用于测试) ====================

async function deployMockContracts() {
  console.log("\n==================== 部署测试依赖合约 ====================");

  // 部署 Mock YD Token
  console.log("\n部署 Mock YD Token...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const ydToken = await MockERC20.deploy("YD Token", "YD", ethers.parseEther("1000000"));
  await ydToken.waitForDeployment();
  const ydTokenAddress = await ydToken.getAddress();
  console.log("✓ YD Token 部署成功:", ydTokenAddress);

  // 部署 Mock Course Contract
  console.log("\n部署 Mock Course Contract...");
  const MockCourseContract = await ethers.getContractFactory("MockCourseContract");
  const courseContract = await MockCourseContract.deploy();
  await courseContract.waitForDeployment();
  const courseContractAddress = await courseContract.getAddress();
  console.log("✓ Course Contract 部署成功:", courseContractAddress);

  return { ydTokenAddress, courseContractAddress };
}

// ==================== 主部署函数 ====================

async function main() {
  console.log("\n==================== CourseDAO 部署脚本 ====================");

  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(deployer.address);

  console.log("\n部署配置:");
  console.log("  网络:", network.name);
  console.log("  部署者:", deployer.address);
  console.log("  余额:", ethers.formatEther(balance), "ETH");
  console.log("  验证合约:", DEPLOYMENT_CONFIG.verify);

  // ==================== 获取依赖合约地址 ====================

  let ydTokenAddress: string;
  let courseContractAddress: string;

  const networkAddresses = NETWORK_ADDRESSES[network.name] || NETWORK_ADDRESSES.localhost;

  // 检查是否需要部署 Mock 合约
  if (
    (network.name === "hardhat" || network.name === "localhost") &&
    (!networkAddresses.ydToken || !networkAddresses.courseContract)
  ) {
    console.log("\n⚠ 未找到依赖合约地址，将部署测试合约...");
    const mockContracts = await deployMockContracts();
    ydTokenAddress = mockContracts.ydTokenAddress;
    courseContractAddress = mockContracts.courseContractAddress;
  } else {
    ydTokenAddress = networkAddresses.ydToken!;
    courseContractAddress = networkAddresses.courseContract!;

    if (!ydTokenAddress || !courseContractAddress) {
      throw new Error(
        "请设置环境变量 YD_TOKEN_ADDRESS 和 COURSE_CONTRACT_ADDRESS，或在 NETWORK_ADDRESSES 中配置"
      );
    }

    console.log("\n使用现有合约地址:");
    console.log("  YD Token:", ydTokenAddress);
    console.log("  Course Contract:", courseContractAddress);
  }

  // ==================== 部署 CourseDAO 合约 ====================

  console.log("\n==================== 部署 CourseDAO 合约 ====================");

  const CourseDAO = await ethers.getContractFactory("CourseDAO");

  console.log("\n部署中...");
  const courseDAO = await CourseDAO.deploy(ydTokenAddress, courseContractAddress);

  await courseDAO.waitForDeployment();
  const courseDaoAddress = await courseDAO.getAddress();

  console.log("✓ CourseDAO 部署成功:", courseDaoAddress);

  // 等待区块确认
  if (DEPLOYMENT_CONFIG.waitConfirmations > 1) {
    console.log(`\n等待 ${DEPLOYMENT_CONFIG.waitConfirmations} 个区块确认...`);
    await sleep(DEPLOYMENT_CONFIG.waitConfirmations * 3000); // 估计每个区块 3 秒
  }

  // ==================== 读取初始配置 ====================

  console.log("\n==================== 读取合约配置 ====================");

  const daoConfig = await courseDAO.getDAOConfig();
  console.log("\nDAO 配置:");
  console.log("  提案押金:", ethers.formatEther(daoConfig.proposalDeposit), "YD");
  console.log("  最小投票权:", ethers.formatEther(daoConfig.minVotingPower), "YD");
  console.log("  投票期限:", Number(daoConfig.votingPeriod) / 86400, "天");
  console.log("  法定人数比例:", Number(daoConfig.quorumPercentage) / 100, "%");
  console.log("  通过阈值:", Number(daoConfig.passThreshold) / 100, "%");
  console.log("  奖励池比例:", Number(daoConfig.rewardPoolPercentage) / 100, "%");

  const admin = await courseDAO.admin();
  console.log("\n管理员:", admin);

  // ==================== 验证合约 ====================

  if (DEPLOYMENT_CONFIG.verify && network.name !== "hardhat" && network.name !== "localhost") {
    console.log("\n等待 30 秒后开始验证合约...");
    await sleep(30000);

    await verifyContract(courseDaoAddress, [ydTokenAddress, courseContractAddress]);
  }

  // ==================== 保存部署信息 ====================

  const deploymentInfo = {
    network: network.name,
    chainId: (await ethers.provider.getNetwork()).chainId.toString(),
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      courseDAO: courseDaoAddress,
      ydToken: ydTokenAddress,
      courseContract: courseContractAddress,
    },
    config: {
      proposalDeposit: daoConfig.proposalDeposit.toString(),
      minVotingPower: daoConfig.minVotingPower.toString(),
      votingPeriod: daoConfig.votingPeriod.toString(),
      quorumPercentage: daoConfig.quorumPercentage.toString(),
      passThreshold: daoConfig.passThreshold.toString(),
      rewardPoolPercentage: daoConfig.rewardPoolPercentage.toString(),
      admin: admin,
    },
    transactionHash: courseDAO.deploymentTransaction()?.hash,
  };

  saveDeploymentInfo(deploymentInfo);

  // ==================== 部署总结 ====================

  console.log("\n==================== 部署完成 ====================");
  console.log("\n已部署合约:");
  console.log("  CourseDAO:", courseDaoAddress);
  console.log("  YD Token:", ydTokenAddress);
  console.log("  Course Contract:", courseContractAddress);

  console.log("\n下一步操作:");
  console.log("1. 确保 YD Token 已分配给用户");
  console.log("2. 确保用户已授权 CourseDAO 合约使用 YD Token");
  console.log("3. (可选) 更新 DAO 配置:");
  console.log("   await courseDAO.updateDAOConfig(...)");
  console.log("4. 开始创建提案:");
  console.log("   await courseDAO.createProposal(courseId, reason)");

  console.log("\n==================== 部署脚本结束 ====================\n");
}

// ==================== 执行部署 ====================

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n部署失败:");
    console.error(error);
    process.exit(1);
  });
