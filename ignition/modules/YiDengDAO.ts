import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import YiDengTokenModule from "./YiDengTokenModule";

/**
 * YiDengDAO 部署模块
 * 
 * 部署参数:
 * - ydTokenAddress: YD 代币合约地址 (如果已部署)
 * - stakeAmount: 创建提案所需质押的 YD 代币数量
 * 
 * 依赖:
 * - 需要先部署 YiDengToken 合约 (或提供已部署的地址)
 */
export default buildModule("YiDengDAOModule", (m) => {
  // 选项1: 使用已部署的 YD Token 地址
  // const ydTokenAddress = m.getParameter("ydTokenAddress");
  
  // 选项2: 在同一个部署脚本中部署 YD Token (推荐用于测试)
  const { ydToken } = m.useModule(YiDengTokenModule);
  const ydTokenAddress = ydToken;

  // 设置质押金额: 默认 100 YD
  // 注意: 需要考虑代币精度，100 YD = 100 * 10^18
  const stakeAmount = m.getParameter(
    "stakeAmount", 
    100000000000000000000n // 100 * 10^18
  );

  // 部署 YiDengDAO 合约
  const ydDAO = m.contract("YiDengDAO", [ydTokenAddress, stakeAmount]);

  // 可选: 向 DAO 合约转入代币作为奖励池
  // 取消注释以下代码来预存奖励代币
  /*
  const rewardPoolAmount = m.getParameter(
    "rewardPoolAmount",
    10000000000000000000000n // 10000 YD
  );
  m.call(ydToken, "mint", [ydDAO, rewardPoolAmount]);
  */

  return { ydDAO, ydToken };
});