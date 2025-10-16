import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import fs from "fs";

export default buildModule("CourseContractModule", (m) => {
  const chainId = 31337;
  // const chainId = 11155111;

  // ✅ 读取 token 地址
  const path = `./ignition/deployments/chain-${chainId}/deployed_addresses.json`;
  if (!fs.existsSync(path)) {
    throw new Error(`❌ 找不到 ${path}，请先部署 SimpleYDTokenModule`);
  }

  const deployed = JSON.parse(fs.readFileSync(path, "utf-8"));
  const tokenAddress = deployed["SimpleYDTokenModule#SimpleYDToken"];

  if (!tokenAddress) {
    throw new Error("❌ deployed_addresses.json 中未找到 SimpleYDTokenModule#SimpleYDToken");
  }

  console.log("✅ SimpleYDToken 合约地址:", tokenAddress);

  // ✅ 获取部署者账户（作为平台管理员）
  const deployer = m.getAccount(0);

  // ✅ 合约部署（第二个参数是平台管理员地址）
  const courseContract = m.contract("CourseContract", [tokenAddress, deployer]);

  // ✅ 讲师地址映射（根据数据库中的钱包地址）
  const INSTRUCTOR_WALLETS: Record<number, Record<string, string>> = {
    31337: {
      // 本地开发网络的讲师地址（使用 hardhat 测试账户）
      "李教授": "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",    // Account #1
      "张老师": "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc",    // Account #2
      "王专家": "0x90f79bf6eb2c4f870365e785982e1f101e93b906",    // Account #3
      "陈工程师": "0x15d34aaf54267db7d7c367839aaf71a00a2c6a65",  // Account #4
      "刘博士": "0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc",    // Account #5
    },
    11155111: {
      // Sepolia 测试网的讲师地址（需要替换为真实地址）
      "李教授": "",
      "张老师": "",
      "王专家": "",
      "陈工程师": "",
      "刘博士": "",
    },
  };

  const instructorWallets = INSTRUCTOR_WALLETS[chainId];
  if (!instructorWallets) {
    throw new Error(`❌ 未配置 chainId ${chainId} 的讲师地址`);
  }

  console.log("✅ 开始创建课程...");

  // ✅ 课程数据（来自数据库）
  // 注意：合约限制最大价格为 500 YDToken，超过的价格已调整
  const courses = [
    {
      id: 1,
      title: "区块链开发入门",
      instructorName: "李教授",
      price: "299",
      totalLessons: 120, // 7200秒 / 60 = 120分钟，假设每课时1分钟
    },
    {
      id: 2,
      title: "Web3 前端开发实战",
      instructorName: "张老师",
      price: "399",
      totalLessons: 180, // 10800秒 / 60 = 180分钟
    },
    {
      id: 3,
      title: "智能合约安全审计",
      instructorName: "王专家",
      price: "499", // 原价 599，调整为 499（合约限制 < 500）
      totalLessons: 240, // 14400秒 / 60 = 240分钟
    },
    {
      id: 4,
      title: "Solidity 智能合约开发",
      instructorName: "陈工程师",
      price: "499",
      totalLessons: 200, // 12000秒 / 60 = 200分钟
    },
    {
      id: 5,
      title: "DeFi 协议开发实战",
      instructorName: "刘博士",
      price: "499", // 原价 799，调整为 499（合约限制 < 500）
      totalLessons: 300, // 18000秒 / 60 = 300分钟
    },
    {
      id: 6,
      title: "NFT 开发完全指南",
      instructorName: "李教授",
      price: "449",
      totalLessons: 160, // 9600秒 / 60 = 160分钟
    },
  ];

  // ✅ 批量认证讲师
  const uniqueInstructors = Array.from(
    new Set(courses.map((c) => instructorWallets[c.instructorName]))
  ).filter(Boolean);

  console.log(`✅ 认证 ${uniqueInstructors.length} 位讲师...`);

  // 批量认证讲师（保存引用）
  const batchCertifyCall = m.call(courseContract, "batchCertifyInstructors", [uniqueInstructors], {
    id: "batchCertifyInstructors",
  });

  // ✅ 创建讲师账户映射（Account #1 到 #5）
  const instructorAccounts: Record<string, any> = {
    "李教授": m.getAccount(1),
    "张老师": m.getAccount(2),
    "王专家": m.getAccount(3),
    "陈工程师": m.getAccount(4),
    "刘博士": m.getAccount(5),
  };

  // ✅ 创建所有课程
  courses.forEach((course) => {
    const instructorWallet = instructorWallets[course.instructorName];
    const instructorAccount = instructorAccounts[course.instructorName];

    if (!instructorWallet || !instructorAccount) {
      console.warn(`⚠️ 警告: 未找到讲师 ${course.instructorName} 的钱包地址，跳过课程 ${course.title}`);
      return;
    }

    // 将价格从数字转换为 wei（假设价格单位是 YDToken，1 YDToken = 10^18 wei）
    const priceInWei = BigInt(course.price) * BigInt(10 ** 18);

    console.log(`✅ 创建课程 ${course.id}: ${course.title}`);
    console.log(`   讲师: ${course.instructorName} (${instructorWallet})`);
    console.log(`   价格: ${course.price} YDToken (${priceInWei} wei)`);
    console.log(`   课时: ${course.totalLessons}`);

    // 创建课程（使用讲师自己的账户调用，after 确保在讲师认证之后执行）
    // 注意：课程创建时自动发布（isPublished: true），无需再调用 publishCourse
    m.call(
      courseContract,
      "createCourse",
      [course.title, instructorWallet, priceInWei, course.totalLessons],
      {
        id: `createCourse${course.id}`,
        from: instructorAccount,
        after: [batchCertifyCall],
      }
    );
  });

  console.log("✅ 所有课程创建完成!");

  return { courseContract };
});
