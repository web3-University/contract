const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * CourseNFTOracle 合约测试
 *
 * 注意: 这些测试模拟了 Chainlink Functions 的行为
 * 实际环境中，fulfillRequest 会由 Chainlink DON 调用
 */

describe("CourseNFTOracle", function () {
  let oracle, nft;
  let owner, student1, student2;
  let mockRouter;

  // Chainlink Functions 配置
  const SUBSCRIPTION_ID = 12345;
  const GAS_LIMIT = 300000;
  const DON_ID = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
  const BASE_URI = "https://api.test.com/metadata/";

  beforeEach(async function () {
    [owner, student1, student2, mockRouter] = await ethers.getSigners();

    // 部署 NFT 合约
    const SimpleYDNFT = await ethers.getContractFactory("SimpleYDNFT");
    nft = await SimpleYDNFT.deploy(BASE_URI);
    await nft.deployed();

    // 部署预言机合约 (使用 mock router)
    const CourseNFTOracle = await ethers.getContractFactory("CourseNFTOracle");
    oracle = await CourseNFTOracle.deploy(
      mockRouter.address, // Mock Chainlink Router
      nft.address,
      DON_ID,
      SUBSCRIPTION_ID,
      GAS_LIMIT
    );
    await oracle.deployed();

    // 将 NFT 所有权转移给预言机
    await nft.transferOwnership(oracle.address);
  });

  describe("部署", function () {
    it("应该正确设置初始状态", async function () {
      expect(await oracle.owner()).to.equal(owner.address);
      expect(await oracle.nftContract()).to.equal(nft.address);
      expect(await oracle.subscriptionId()).to.equal(SUBSCRIPTION_ID);
      expect(await oracle.gasLimit()).to.equal(GAS_LIMIT);
      expect(await oracle.donId()).to.equal(DON_ID);
    });

    it("应该有默认的 JavaScript 源代码", async function () {
      const source = await oracle.source();
      expect(source.length).to.be.greaterThan(0);
      expect(source).to.include("Functions.makeHttpRequest");
    });

    it("NFT 所有权应该是预言机合约", async function () {
      expect(await nft.owner()).to.equal(oracle.address);
    });
  });

  describe("请求课程验证", function () {
    const courseId = 101;
    const courseName = "区块链基础课程";

    it("应该能够请求单个课程验证", async function () {
      const tx = await oracle.requestCourseCompletion(
        student1.address,
        courseId,
        courseName
      );

      const receipt = await tx.wait();

      // 检查事件
      const event = receipt.events.find((e) => e.event === "RequestSent");
      expect(event).to.not.be.undefined;
      expect(event.args.student).to.equal(student1.address);
      expect(event.args.courseId).to.equal(courseId);
      expect(event.args.courseName).to.equal(courseName);

      const requestId = event.args.requestId;

      // 检查请求状态
      const request = await oracle.getRequest(requestId);
      expect(request.student).to.equal(student1.address);
      expect(request.courseId).to.equal(courseId);
      expect(request.courseName).to.equal(courseName);
      expect(request.fulfilled).to.be.false;
      expect(request.success).to.be.false;
    });

    it("应该拒绝空地址", async function () {
      await expect(
        oracle.requestCourseCompletion(
          ethers.constants.AddressZero,
          courseId,
          courseName
        )
      ).to.be.revertedWithCustomError(oracle, "InvalidAddress");
    });

    it("应该拒绝空课程名称", async function () {
      await expect(
        oracle.requestCourseCompletion(student1.address, courseId, "")
      ).to.be.revertedWithCustomError(oracle, "InvalidCourseData");
    });

    it("应该检测待处理的请求", async function () {
      await oracle.requestCourseCompletion(
        student1.address,
        courseId,
        courseName
      );

      const hasPending = await oracle.hasPendingRequest(
        student1.address,
        courseId
      );
      expect(hasPending).to.be.true;
    });

    it("应该防止重复的待处理请求", async function () {
      await oracle.requestCourseCompletion(
        student1.address,
        courseId,
        courseName
      );

      await expect(
        oracle.requestCourseCompletion(student1.address, courseId, courseName)
      ).to.be.revertedWithCustomError(oracle, "RequestAlreadyPending");
    });
  });

  describe("批量请求", function () {
    it("应该能够批量请求", async function () {
      const students = [student1.address, student2.address];
      const courseIds = [101, 102];
      const courseNames = ["课程1", "课程2"];

      const tx = await oracle.batchRequestCourseCompletion(
        students,
        courseIds,
        courseNames
      );

      const receipt = await tx.wait();

      // 应该有 2 个 RequestSent 事件
      const events = receipt.events.filter((e) => e.event === "RequestSent");
      expect(events.length).to.equal(2);
    });

    it("应该拒绝长度不匹配的数组", async function () {
      const students = [student1.address, student2.address];
      const courseIds = [101]; // 长度不匹配
      const courseNames = ["课程1", "课程2"];

      await expect(
        oracle.batchRequestCourseCompletion(students, courseIds, courseNames)
      ).to.be.revertedWith("Array lengths mismatch");
    });
  });

  describe("查询功能", function () {
    let requestId;
    const courseId = 101;
    const courseName = "测试课程";

    beforeEach(async function () {
      const tx = await oracle.requestCourseCompletion(
        student1.address,
        courseId,
        courseName
      );
      const receipt = await tx.wait();
      const event = receipt.events.find((e) => e.event === "RequestSent");
      requestId = event.args.requestId;
    });

    it("应该能够查询请求详情", async function () {
      const request = await oracle.getRequest(requestId);

      expect(request.student).to.equal(student1.address);
      expect(request.courseId).to.equal(courseId);
      expect(request.courseName).to.equal(courseName);
      expect(request.fulfilled).to.be.false;
    });

    it("应该能够通过学生和课程查询请求ID", async function () {
      const retrievedRequestId = await oracle.getStudentCourseRequestId(
        student1.address,
        courseId
      );

      expect(retrievedRequestId).to.equal(requestId);
    });

    it("应该能够检查待处理请求", async function () {
      const hasPending = await oracle.hasPendingRequest(
        student1.address,
        courseId
      );

      expect(hasPending).to.be.true;
    });

    it("对于不存在的请求应该返回 false", async function () {
      const hasPending = await oracle.hasPendingRequest(student2.address, 999);
      expect(hasPending).to.be.false;
    });
  });

  describe("管理员功能", function () {
    it("应该能够更新源代码", async function () {
      const newSource = "new source code";

      await expect(oracle.updateSource(newSource))
        .to.emit(oracle, "SourceCodeUpdated")
        .withArgs(newSource);

      expect(await oracle.source()).to.equal(newSource);
    });

    it("非 owner 不能更新源代码", async function () {
      await expect(
        oracle.connect(student1).updateSource("new source")
      ).to.be.revertedWithCustomError(oracle, "UnauthorizedCaller");
    });

    it("应该能够更新配置", async function () {
      const newSubId = 99999;
      const newGasLimit = 400000;
      const newDonId = "0x1234567890123456789012345678901234567890123456789012345678901234";

      await expect(oracle.updateConfig(newSubId, newGasLimit, newDonId))
        .to.emit(oracle, "ConfigUpdated")
        .withArgs(newSubId, newGasLimit, newDonId);

      expect(await oracle.subscriptionId()).to.equal(newSubId);
      expect(await oracle.gasLimit()).to.equal(newGasLimit);
      expect(await oracle.donId()).to.equal(newDonId);
    });

    it("应该能够更新 NFT 合约", async function () {
      // 部署新的 NFT 合约
      const SimpleYDNFT = await ethers.getContractFactory("SimpleYDNFT");
      const newNFT = await SimpleYDNFT.deploy(BASE_URI);
      await newNFT.deployed();

      await oracle.updateNFTContract(newNFT.address);

      expect(await oracle.nftContract()).to.equal(newNFT.address);
    });

    it("应该拒绝零地址的 NFT 合约", async function () {
      await expect(
        oracle.updateNFTContract(ethers.constants.AddressZero)
      ).to.be.revertedWithCustomError(oracle, "InvalidAddress");
    });

    it("应该能够转移所有权", async function () {
      await oracle.transferOwnership(student1.address);

      expect(await oracle.owner()).to.equal(student1.address);
    });
  });

  describe("NFT 查询", function () {
    it("学生初始应该没有 NFT", async function () {
      const balance = await nft.balanceOf(student1.address);
      expect(balance).to.equal(0);
    });

    it("应该能够查询证书存在性", async function () {
      const hasCert = await nft.hasCertificate(student1.address, 101);
      expect(hasCert).to.be.false;
    });
  });

  describe("工具函数", function () {
    // 注意: _addressToString 和 _uint256ToString 是内部函数
    // 这里只是展示如何在合约中使用它们的效果

    it("应该正确构建请求参数", async function () {
      const courseId = 101;
      const courseName = "测试课程";

      const tx = await oracle.requestCourseCompletion(
        student1.address,
        courseId,
        courseName
      );

      // 如果参数转换有问题，请求会失败
      await expect(tx).to.not.be.reverted;
    });
  });
});

/**
 * 集成测试示例 (需要实际的 Chainlink Functions)
 *
 * 这些测试需要在测试网上运行，并且需要实际的 Chainlink Functions 订阅
 */

describe("CourseNFTOracle 集成测试", function () {
  // 跳过集成测试 (除非设置了环境变量)
  const INTEGRATION_TEST = process.env.INTEGRATION_TEST === "true";

  if (!INTEGRATION_TEST) {
    it.skip("需要设置 INTEGRATION_TEST=true 环境变量");
    return;
  }

  // 集成测试代码...
  it("应该能够完整地验证课程并铸造 NFT", async function () {
    this.timeout(120000); // 2分钟超时

    // 实际的集成测试代码
    // ...
  });
});
