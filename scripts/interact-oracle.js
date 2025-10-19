/**
 * 预言机合约交互脚本
 *
 * 使用方法:
 * npx hardhat run scripts/interact-oracle.js --network sepolia
 */

const hre = require("hardhat");

// ==================== 配置 ====================

// 从部署文件或环境变量中获取合约地址
const ORACLE_ADDRESS = process.env.ORACLE_ADDRESS || "YOUR_ORACLE_ADDRESS";
const NFT_ADDRESS = process.env.NFT_ADDRESS || "YOUR_NFT_ADDRESS";

// ==================== 主函数 ====================

async function main() {
  const [signer] = await hre.ethers.getSigners();
  const network = hre.network.name;

  console.log("\n==================== 预言机交互 ====================");
  console.log("Network:", network);
  console.log("Signer:", signer.address);
  console.log("Balance:", hre.ethers.utils.formatEther(await signer.getBalance()), "ETH");

  // 获取合约实例
  const oracle = await hre.ethers.getContractAt("CourseNFTOracle", ORACLE_ADDRESS);
  const nft = await hre.ethers.getContractAt("SimpleYDNFT", NFT_ADDRESS);

  console.log("\nOracle Contract:", oracle.address);
  console.log("NFT Contract:", nft.address);

  // 显示菜单
  console.log("\n选择操作:");
  console.log("1. 请求单个课程验证");
  console.log("2. 批量请求课程验证");
  console.log("3. 查询请求状态");
  console.log("4. 查询学生 NFT");
  console.log("5. 更新 JavaScript 源代码");
  console.log("6. 查看合约配置");

  // 这里可以添加交互式命令行界面
  // 为了演示，直接执行一些操作

  await demonstrateUsage(oracle, nft, signer);
}

// ==================== 演示函数 ====================

async function demonstrateUsage(oracle, nft, signer) {
  console.log("\n==================== 演示操作 ====================");

  // ==================== 1. 请求课程验证 ====================

  console.log("\n>>> 1. 请求课程验证");

  const studentAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"; // 示例地址
  const courseId = 101;
  const courseName = "区块链基础课程";

  console.log(`为学生 ${studentAddress} 请求课程 ${courseId} 的验证...`);

  try {
    // 检查是否有待处理的请求
    const hasPending = await oracle.hasPendingRequest(studentAddress, courseId);

    if (hasPending) {
      console.log("该学生已有待处理的请求");
    } else {
      const tx = await oracle.requestCourseCompletion(
        studentAddress,
        courseId,
        courseName
      );

      console.log("Transaction sent:", tx.hash);
      console.log("Waiting for confirmation...");

      const receipt = await tx.wait();

      // 从事件中获取 Request ID
      const event = receipt.events.find((e) => e.event === "RequestSent");

      if (event) {
        const requestId = event.args.requestId;
        console.log("Request ID:", requestId);

        // 保存 Request ID 以便后续查询
        console.log("\n保存此 Request ID 用于后续查询");
      }
    }
  } catch (error) {
    console.error("请求失败:", error.message);
  }

  // ==================== 2. 批量请求 ====================

  console.log("\n>>> 2. 批量请求课程验证");

  const students = [
    "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
    "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2",
  ];

  const courseIds = [101, 102, 103];
  const courseNames = ["区块链基础", "智能合约开发", "DeFi 原理"];

  console.log(`批量请求 ${students.length} 个学生的课程验证...`);

  try {
    const tx = await oracle.batchRequestCourseCompletion(
      students,
      courseIds,
      courseNames
    );

    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();

    console.log("批量请求已提交");
  } catch (error) {
    console.error("批量请求失败:", error.message);
  }

  // ==================== 3. 查询请求状态 ====================

  console.log("\n>>> 3. 查询请求状态");

  const requestId = "0x..."; // 替换为实际的 Request ID

  try {
    const request = await oracle.getRequest(requestId);

    console.log("请求详情:");
    console.log("  Student:", request.student);
    console.log("  Course ID:", request.courseId.toString());
    console.log("  Course Name:", request.courseName);
    console.log("  Timestamp:", new Date(request.timestamp * 1000).toISOString());
    console.log("  Fulfilled:", request.fulfilled);
    console.log("  Success:", request.success);
  } catch (error) {
    console.error("查询失败:", error.message);
  }

  // ==================== 4. 查询学生 NFT ====================

  console.log("\n>>> 4. 查询学生 NFT");

  try {
    const balance = await nft.balanceOf(studentAddress);
    console.log(`学生拥有 ${balance} 个 NFT`);

    if (balance > 0) {
      const tokens = await nft.getTokensByOwner(studentAddress);
      console.log("Token IDs:", tokens.map((t) => t.toString()));

      // 查询第一个 NFT 的证书信息
      if (tokens.length > 0) {
        const certificate = await nft.getCertificate(tokens[0]);
        console.log("\n第一个 NFT 的证书信息:");
        console.log("  Course ID:", certificate.courseId.toString());
        console.log("  Course Name:", certificate.courseName);
        console.log("  Completion Time:", new Date(certificate.completionTime * 1000).toISOString());
      }
    }
  } catch (error) {
    console.error("查询失败:", error.message);
  }

  // ==================== 5. 查看合约配置 ====================

  console.log("\n>>> 5. 查看合约配置");

  try {
    const subscriptionId = await oracle.subscriptionId();
    const gasLimit = await oracle.gasLimit();
    const donId = await oracle.donId();
    const owner = await oracle.owner();

    console.log("Chainlink Functions 配置:");
    console.log("  Subscription ID:", subscriptionId.toString());
    console.log("  Gas Limit:", gasLimit.toString());
    console.log("  DON ID:", donId);
    console.log("  Owner:", owner);
  } catch (error) {
    console.error("查询失败:", error.message);
  }
}

// ==================== 监听事件 ====================

async function listenToEvents(oracle, nft) {
  console.log("\n==================== 监听事件 ====================");

  // 监听请求发送事件
  oracle.on("RequestSent", (requestId, student, courseId, courseName) => {
    console.log("\n[RequestSent Event]");
    console.log("  Request ID:", requestId);
    console.log("  Student:", student);
    console.log("  Course ID:", courseId.toString());
    console.log("  Course Name:", courseName);
  });

  // 监听请求完成事件
  oracle.on("RequestFulfilled", (requestId, student, courseId, success, tokenId) => {
    console.log("\n[RequestFulfilled Event]");
    console.log("  Request ID:", requestId);
    console.log("  Student:", student);
    console.log("  Course ID:", courseId.toString());
    console.log("  Success:", success);

    if (success) {
      console.log("  NFT Token ID:", tokenId.toString());
      console.log("  🎉 NFT 铸造成功!");
    } else {
      console.log("  ❌ 验证失败或 NFT 铸造失败");
    }
  });

  // 监听 NFT 铸造事件
  nft.on("NFTMinted", (to, tokenId, courseId, courseName) => {
    console.log("\n[NFTMinted Event]");
    console.log("  Recipient:", to);
    console.log("  Token ID:", tokenId.toString());
    console.log("  Course ID:", courseId.toString());
    console.log("  Course Name:", courseName);
  });

  console.log("事件监听已启动... (按 Ctrl+C 停止)");

  // 保持脚本运行
  await new Promise(() => {});
}

// ==================== 更新源代码示例 ====================

async function updateSourceCode(oracle) {
  console.log("\n==================== 更新 JavaScript 源代码 ====================");

  // 新的 JavaScript 源代码
  const newSource = `
const studentAddress = args[0];
const courseId = args[1];

// 调用你的 API
const response = await Functions.makeHttpRequest({
  url: \`https://your-api.com/courses/\${courseId}/students/\${studentAddress}/completion\`,
  method: "GET",
  headers: {
    "Content-Type": "application/json"
  }
});

if (response.error) {
  throw Error("API request failed");
}

const data = response.data;

// 返回 1 表示完成，0 表示未完成
return Functions.encodeUint256(data.completed ? 1 : 0);
`;

  console.log("更新源代码...");

  try {
    const tx = await oracle.updateSource(newSource);
    await tx.wait();

    console.log("源代码更新成功");
  } catch (error) {
    console.error("更新失败:", error.message);
  }
}

// ==================== 工具函数 ====================

// 从文件加载最新的部署信息
function loadLatestDeployment(network) {
  const fs = require("fs");
  const path = require("path");

  const deploymentsDir = path.join(__dirname, "../deployments");

  if (!fs.existsSync(deploymentsDir)) {
    throw new Error("Deployments directory not found");
  }

  const files = fs
    .readdirSync(deploymentsDir)
    .filter((f) => f.startsWith(network) && f.endsWith(".json"))
    .sort()
    .reverse();

  if (files.length === 0) {
    throw new Error(`No deployment found for network ${network}`);
  }

  const filepath = path.join(deploymentsDir, files[0]);
  const data = JSON.parse(fs.readFileSync(filepath, "utf8"));

  return data;
}

// ==================== 执行脚本 ====================

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
