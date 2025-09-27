import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("SimpleYDTokenModule", (m) => {
  const simpleYDToken = m.contract("SimpleYDToken");

  return { simpleYDToken };
});
