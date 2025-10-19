import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import fs from "fs";

/**
 * CourseDAO 部署模块
 *
 * 功能说明:
 * - 部署 CourseDAO 投票治理合约
 * - 自动从部署记录文件中读取依赖合约地址
 *
 * 使用方法:
 * 1. 确保已部署依赖合约:
 *    npx hardhat ignition deploy ./ignition/modules/SimpleYDToken.ts --network localhost
 *    npx hardhat ignition deploy ./ignition/modules/CourseContract.ts --network localhost
 *
 * 2. 部署 CourseDAO:
 *    npx hardhat ignition deploy ./ignition/modules/CourseDAO.ts --network localhost
 *
 * 注意:
 * - 修改 chainId 以适配不同网络 (31337 本地, 11155111 Sepolia)
 */
export default buildModule("CourseDAOModule", (m) => {
  const chainId = 31337;
  // const chainId = 11155111;

  // ==================== 读取依赖合约地址 ====================

  // 读取部署记录文件
  const path = `./ignition/deployments/chain-${chainId}/deployed_addresses.json`;
  if (!fs.existsSync(path)) {
    throw new Error(`❌ 找不到 ${path}，请先部署依赖合约`);
  }

  const deployed = JSON.parse(fs.readFileSync(path, "utf-8"));

  // 读取 YD Token 地址
  const ydTokenAddress = deployed["SimpleYDTokenModule#SimpleYDToken"];
  if (!ydTokenAddress) {
    throw new Error("❌ deployed_addresses.json 中未找到 SimpleYDTokenModule#SimpleYDToken");
  }
  console.log("✅ YD Token 合约地址:", ydTokenAddress);

  // 读取 Course Contract 地址
  const courseContractAddress = deployed["CourseContractModule#CourseContract"];
  if (!courseContractAddress) {
    throw new Error("❌ deployed_addresses.json 中未找到 CourseContractModule#CourseContract");
  }
  console.log("✅ Course Contract 合约地址:", courseContractAddress);

  // ==================== 部署 CourseDAO 合约 ====================

  console.log("\n==================== 部署 CourseDAO 合约 ====================");

  const courseDAO = m.contract("CourseDAO", [ydTokenAddress, courseContractAddress], {
    id: "CourseDAO"
  });

  console.log("✅ CourseDAO 部署配置完成");

  return { courseDAO };
});
