import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("CourseContractModule", (m) => {
  const courseContract = m.contract("CourseContract", ['0xA812265c869F2BCB755980677812F253459A0cc7','0xA812265c869F2BCB755980677812F253459A0cc7']);

  return { courseContract };
});
