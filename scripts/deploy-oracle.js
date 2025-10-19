/**
 * Chainlink Functions 预言机合约部署脚本
 *
 * 使用方法:
 * npx hardhat run scripts/deploy-oracle.js --network sepolia
 */

const hre = require("hardhat");

// ==================== 网络配置 ====================

const NETWORK_CONFIG = {
  // Sepolia 测试网
  sepolia: {
    router: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
    donId: "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000",
    linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    subscriptionId: process.env.SEPOLIA_SUBSCRIPTION_ID || 0,
  },

  // Polygon Mumbai 测试网
  mumbai: {
    router: "0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C",
    donId: "0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000",
    linkToken: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    subscriptionId: process.env.MUMBAI_SUBSCRIPTION_ID || 0,
  },

  // Avalanche Fuji 测试网
  fuji: {
    router: "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0",
    donId: "0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000",
    linkToken: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
    subscriptionId: process.env.FUJI_SUBSCRIPTION_ID || 0,
  },
};

// ==================== 部署配置 ====================

const DEPLOYMENT_CONFIG = {
  // NFT 元数据基础 URI
  baseTokenURI: process.env.BASE_TOKEN_URI || "https://api.web3university.com/metadata/",

  // Chainlink Functions Gas Limit
  gasLimit: 300000,

  // 是否验证合约 (在区块链浏览器上)
  verify: process.env.VERIFY === "true",
};

// ==================== 主函数 ====================

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const network = hre.network.name;

  console.log("\n==================== 部署配置 ====================");
  console.log("Network:", network);
  console.log("Deployer:", deployer.address);
  console.log("Balance:", hre.ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  // 获取网络配置
  const config = NETWORK_CONFIG[network];
  if (!config) {
    throw new Error(`Network ${network} not configured`);
  }

  if (!config.subscriptionId || config.subscriptionId === 0) {
    throw new Error(`Please set ${network.toUpperCase()}_SUBSCRIPTION_ID in .env file`);
  }

  console.log("\nChainlink Functions 配置:");
  console.log("  Router:", config.router);
  console.log("  DON ID:", config.donId);
  console.log("  Subscription ID:", config.subscriptionId);
  console.log("  Gas Limit:", DEPLOYMENT_CONFIG.gasLimit);

  // ==================== 步骤 1: 部署 NFT 合约 ====================

  console.log("\n==================== 部署 NFT 合约 ====================");

  const SimpleYDNFT = await hre.ethers.getContractFactory("SimpleYDNFT");
  const nft = await SimpleYDNFT.deploy(DEPLOYMENT_CONFIG.baseTokenURI);
  await nft.deployed();

  console.log("NFT Contract deployed to:", nft.address);
  console.log("Transaction hash:", nft.deployTransaction.hash);

  // 等待几个区块确认
  console.log("Waiting for confirmations...");
  await nft.deployTransaction.wait(5);

  // ==================== 步骤 2: 部署预言机合约 ====================

  console.log("\n==================== 部署预言机合约 ====================");

  const CourseNFTOracle = await hre.ethers.getContractFactory("CourseNFTOracle");
  const oracle = await CourseNFTOracle.deploy(
    config.router,
    nft.address,
    config.donId,
    config.subscriptionId,
    DEPLOYMENT_CONFIG.gasLimit
  );
  await oracle.deployed();

  console.log("Oracle Contract deployed to:", oracle.address);
  console.log("Transaction hash:", oracle.deployTransaction.hash);

  // 等待几个区块确认
  console.log("Waiting for confirmations...");
  await oracle.deployTransaction.wait(5);

  // ==================== 步骤 3: 转移 NFT 所有权 ====================

  console.log("\n==================== 配置合约权限 ====================");

  console.log("Transferring NFT ownership to Oracle...");
  const transferTx = await nft.transferOwnership(oracle.address);
  await transferTx.wait();

  console.log("NFT ownership transferred successfully");

  // ==================== 步骤 4: 验证合约 ====================

  if (DEPLOYMENT_CONFIG.verify) {
    console.log("\n==================== 验证合约 ====================");

    console.log("Waiting 30 seconds before verification...");
    await sleep(30000);

    try {
      console.log("\nVerifying NFT Contract...");
      await hre.run("verify:verify", {
        address: nft.address,
        constructorArguments: [DEPLOYMENT_CONFIG.baseTokenURI],
      });
    } catch (error) {
      console.log("NFT verification failed:", error.message);
    }

    try {
      console.log("\nVerifying Oracle Contract...");
      await hre.run("verify:verify", {
        address: oracle.address,
        constructorArguments: [
          config.router,
          nft.address,
          config.donId,
          config.subscriptionId,
          DEPLOYMENT_CONFIG.gasLimit,
        ],
      });
    } catch (error) {
      console.log("Oracle verification failed:", error.message);
    }
  }

  // ==================== 部署总结 ====================

  console.log("\n==================== 部署完成 ====================");
  console.log("\n合约地址:");
  console.log("  NFT Contract:", nft.address);
  console.log("  Oracle Contract:", oracle.address);

  console.log("\n下一步操作:");
  console.log("1. 访问 Chainlink Functions Dashboard:");
  console.log("   https://functions.chain.link/");
  console.log("\n2. 将 Oracle 合约添加为 Consumer:");
  console.log("   Subscription ID:", config.subscriptionId);
  console.log("   Consumer Address:", oracle.address);
  console.log("\n3. 确保订阅中有足够的 LINK 代币");
  console.log("   最少建议: 5 LINK");

  console.log("\n4. (可选) 自定义 JavaScript 源代码:");
  console.log("   await oracle.updateSource(newSourceCode);");

  // ==================== 保存部署信息 ====================

  const deploymentInfo = {
    network: network,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      nft: nft.address,
      oracle: oracle.address,
    },
    config: {
      router: config.router,
      donId: config.donId,
      subscriptionId: config.subscriptionId,
      gasLimit: DEPLOYMENT_CONFIG.gasLimit,
      baseTokenURI: DEPLOYMENT_CONFIG.baseTokenURI,
    },
  };

  const fs = require("fs");
  const path = require("path");

  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  const filename = `${network}-${Date.now()}.json`;
  const filepath = path.join(deploymentsDir, filename);

  fs.writeFileSync(filepath, JSON.stringify(deploymentInfo, null, 2));

  console.log("\n部署信息已保存至:", filepath);
  console.log("\n==================== 部署脚本结束 ====================\n");
}

// ==================== 辅助函数 ====================

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ==================== 执行部署 ====================

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
