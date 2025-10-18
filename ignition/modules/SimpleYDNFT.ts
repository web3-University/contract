import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("SimpleYDNFTModule", (m) => {
  // 设置NFT元数据的基础URI
  const baseURI = m.getParameter("baseURI", "https://api.yideng.edu/nft/metadata/");

  const simpleYDNFT = m.contract("SimpleYDNFT", [baseURI]);

  return { simpleYDNFT };
});
