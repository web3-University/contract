import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * YiDengNFT 部署模块
 * 
 * 部署参数:
 * - initialOwner: 合约初始所有者地址
 * 
 * 部署后可选操作:
 * - 铸造初始 NFT (如果需要)
 */
export default buildModule("YiDengNFTModule", (m) => {
  // 获取部署参数
  const initialOwner = m.getParameter("initialOwner", m.getAccount(0));
  
  // 部署 YiDengNFT 合约
  const ydNFT = m.contract("YiDengNFT", [initialOwner]);

  // 可选: 铸造初始 NFT
  // 取消注释以下代码来铸造初始 NFT
  /*
  const recipient = m.getParameter("nftRecipient", initialOwner);
  const tokenURI = m.getParameter("tokenURI", "ipfs://QmExample");
  m.call(ydNFT, "safeMint", [recipient, tokenURI]);
  */

  return { ydNFT };
});