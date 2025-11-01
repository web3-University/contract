import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * YiDengToken 部署模块
 * 
 * 部署参数:
 * - initialOwner: 合约初始所有者地址
 * 
 * 部署后操作:
 * - 设置兑换比例 (例如: 1 ETH = 4000 YD)
 */
export default buildModule("YiDengTokenModule", (m) => {
  // 合约拥有者地址
  const initialOwner = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266';
  
  // 部署 YiDengToken 合约
  const ydToken = m.contract("YiDengToken", [initialOwner]);

  // 设置兑换比例: 1 ETH = 4000 YD
  // 注意: 这里的比例可以根据实际需求调整
  const exchangeRate = m.getParameter("exchangeRate", 4000n);
  m.call(ydToken, "setExchangeRate", [exchangeRate]);

  return { ydToken };
});