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

  // ✅ 合约部署
  const courseContract = m.contract("CourseContract", [tokenAddress, tokenAddress]);

  // ✅ 讲师地址
  const INSTRUCTOR_ADDRESS: Record<number, string> = {
    31337: "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
    11155111: "",
  };

  const instructor = INSTRUCTOR_ADDRESS[chainId];
  if (!instructor) throw new Error(`❌ 未配置 chainId ${chainId} 的讲师地址`);

  console.log("✅ CourseContract 讲师地址:", instructor);

  // ✅ 调用创建课程
  m.call(courseContract, "createCourse", [
    "Solidity从入门到精通",
    instructor,
    100000000000000000000n,
  ], { id: 'createCourse1' });

  console.log("✅ 创建课程成功");

  return { courseContract };
});
