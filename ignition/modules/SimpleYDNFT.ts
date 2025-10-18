import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("SimpleYDNFTModule", (m) => {
  // 设置NFT元数据的基础URI
  const baseURI = m.getParameter("baseURI", "ipfs://bafybeig2ocejfpopvwu3qemwpyoe6nn42k7ln4bvayeueep6tnzyuedysi/");

  const simpleYDNFT = m.contract("SimpleYDNFT", [baseURI]);

  // Mint一个NFT
  m.call(simpleYDNFT, "mintCertificate", [
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // to地址
    1, // courseId
    "区块链开发入门", // courseName
    Math.floor(Date.now() / 1000) // completionTime (当前时间戳)
  ]);

  return { simpleYDNFT };
});
