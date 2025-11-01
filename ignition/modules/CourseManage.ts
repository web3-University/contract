import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as fs from "fs";

/**
 * CourseManage 部署模块
 * 
 * 部署参数:
 * - ydTokenAddress: YD 代币合约地址 (如果已部署)
 * - platformAddress: 平台收款地址
 * 
 * 依赖:
 * - 需要先部署 YiDengToken 合约 (或提供已部署的地址)
 */
export default buildModule("CourseManageModule", (m) => {
    const chainId = 31337;
  // const chainId = 11155111;

  // ✅ 读取 YDToken 地址
  const path = `./ignition/deployments/chain-${chainId}/deployed_addresses.json`;
  if (!fs.existsSync(path)) {
    throw new Error(`❌ 找不到 ${path}，请先部署 SimpleYDTokenModule`);
  }

  const deployed = JSON.parse(fs.readFileSync(path, "utf-8"));
  const ydTokenAddress = deployed["YiDengTokenModule#YiDengToken"];

  if (!ydTokenAddress) {
    throw new Error("❌ deployed_addresses.json 中未找到 YiDengTokenModule#YiDengToken");
  }

  console.log("✅ SimpleYDToken 合约地址:", ydTokenAddress);

  // 获取平台地址参数
  const platformAddress = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';

  // 部署 CourseManage 合约
  const courseManage = m.contract("CourseManage", [
    ydTokenAddress,
    platformAddress
  ]);

  return { courseManage };
});