import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";

/**
 * MockContracts 模块
 *
 * 用于本地测试环境部署 Mock 合约
 * - MockERC20 (YD Token)
 * - MockCourseContract
 */
export default buildModule("MockContractsModule", (m) => {
  console.log("==================== 部署测试依赖合约 ====================");

  // 部署 Mock YD Token
  console.log("\n部署 Mock YD Token...");
  const mockYDToken = m.contract("MockERC20", [
    "YD Token",
    "YD",
    parseEther("1000000") // 初始供应量: 1,000,000 YD
  ], {
    id: "MockYDToken"
  });

  console.log("✓ YD Token 部署配置完成");

  // 部署 Mock Course Contract
  console.log("\n部署 Mock Course Contract...");
  const mockCourseContract = m.contract("MockCourseContract", [], {
    id: "MockCourseContract"
  });

  console.log("✓ Course Contract 部署配置完成");

  return {
    mockYDToken,
    mockCourseContract
  };
});
