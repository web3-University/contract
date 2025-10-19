// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "./tokens/SimpleYDNFT.sol";

/**
 * @title CourseNFTOracle
 * @dev 使用 Chainlink Functions 的课程完成验证与 NFT 铸造合约
 * @notice 该合约通过 Chainlink Functions 调用链下 API 验证学生课程完成状态，并在验证通过后铸造 NFT
 */
contract CourseNFTOracle is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // ==================== 状态变量 ====================

    // NFT 合约实例
    SimpleYDNFT public nftContract;

    // Chainlink Functions 相关配置
    bytes32 public donId;                    // DON (Decentralized Oracle Network) ID
    uint64 public subscriptionId;            // Chainlink Functions 订阅 ID
    uint32 public gasLimit;                  // 回调函数的 gas 限制

    // 管理员
    address public owner;

    // JavaScript 源代码 (链下执行的代码)
    string public source;

    // ==================== 数据结构 ====================

    /**
     * @dev 课程完成请求信息
     */
    struct CourseCompletionRequest {
        address student;           // 学生地址
        uint256 courseId;          // 课程 ID
        string courseName;         // 课程名称
        uint256 timestamp;         // 请求时间
        bool fulfilled;            // 是否已完成
        bool success;              // 是否成功
    }

    // 请求 ID => 请求信息
    mapping(bytes32 => CourseCompletionRequest) public requests;

    // 学生地址 => 课程 ID => 请求 ID
    mapping(address => mapping(uint256 => bytes32)) public studentCourseRequests;

    // ==================== 事件 ====================

    event RequestSent(
        bytes32 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        string courseName
    );

    event RequestFulfilled(
        bytes32 indexed requestId,
        address indexed student,
        uint256 indexed courseId,
        bool success,
        uint256 tokenId
    );

    event SourceCodeUpdated(string newSource);
    event ConfigUpdated(uint64 subscriptionId, uint32 gasLimit, bytes32 donId);

    // ==================== 错误定义 ====================

    error UnauthorizedCaller();
    error InvalidAddress();
    error RequestAlreadyPending();
    error RequestNotFound();
    error UnexpectedRequestID(bytes32 requestId);
    error InvalidCourseData();

    // ==================== 修饰符 ====================

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedCaller();
        _;
    }

    // ==================== 构造函数 ====================

    /**
     * @param router Chainlink Functions Router 地址
     * @param _nftContract NFT 合约地址
     * @param _donId DON ID
     * @param _subscriptionId Chainlink Functions 订阅 ID
     * @param _gasLimit 回调函数 gas 限制
     */
    constructor(
        address router,
        address _nftContract,
        bytes32 _donId,
        uint64 _subscriptionId,
        uint32 _gasLimit
    ) FunctionsClient(router) {
        if (_nftContract == address(0)) revert InvalidAddress();

        owner = msg.sender;
        nftContract = SimpleYDNFT(_nftContract);
        donId = _donId;
        subscriptionId = _subscriptionId;
        gasLimit = _gasLimit;

        // 默认的 JavaScript 源代码
        source =
            "const studentAddress = args[0];"
            "const courseId = args[1];"
            "const apiUrl = `https://api.example.com/courses/${courseId}/students/${studentAddress}/completion`;"
            "const response = await Functions.makeHttpRequest({"
            "  url: apiUrl,"
            "  method: 'GET'"
            "});"
            "if (response.error) {"
            "  throw Error('API request failed');"
            "}"
            "const data = response.data;"
            "if (data.completed === true) {"
            "  return Functions.encodeUint256(1);"
            "} else {"
            "  return Functions.encodeUint256(0);"
            "}";
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 请求验证课程完成状态并铸造 NFT
     * @param student 学生地址
     * @param courseId 课程 ID
     * @param courseName 课程名称
     * @return requestId Chainlink Functions 请求 ID
     */
    function requestCourseCompletion(
        address student,
        uint256 courseId,
        string calldata courseName
    ) external returns (bytes32 requestId) {
        if (student == address(0)) revert InvalidAddress();
        if (bytes(courseName).length == 0) revert InvalidCourseData();

        // 检查是否已有待处理的请求
        bytes32 existingRequestId = studentCourseRequests[student][courseId];
        if (existingRequestId != bytes32(0) && !requests[existingRequestId].fulfilled) {
            revert RequestAlreadyPending();
        }

        // 构建 Chainlink Functions 请求
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);

        // 设置参数: [学生地址, 课程ID]
        string[] memory args = new string[](2);
        args[0] = _addressToString(student);
        args[1] = _uint256ToString(courseId);
        req.setArgs(args);

        // 发送请求
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );

        // 保存请求信息
        requests[requestId] = CourseCompletionRequest({
            student: student,
            courseId: courseId,
            courseName: courseName,
            timestamp: block.timestamp,
            fulfilled: false,
            success: false
        });

        studentCourseRequests[student][courseId] = requestId;

        emit RequestSent(requestId, student, courseId, courseName);

        return requestId;
    }

    /**
     * @dev Chainlink Functions 回调函数
     * @param requestId 请求 ID
     * @param response 响应数据
     * @param err 错误信息
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        CourseCompletionRequest storage request = requests[requestId];

        if (request.student == address(0)) {
            revert UnexpectedRequestID(requestId);
        }

        request.fulfilled = true;

        // 检查是否有错误
        if (err.length > 0) {
            request.success = false;
            emit RequestFulfilled(requestId, request.student, request.courseId, false, 0);
            return;
        }

        // 解码响应 (0 = 未完成, 1 = 已完成)
        uint256 completionStatus = abi.decode(response, (uint256));

        if (completionStatus == 1) {
            // 学生已完成课程，铸造 NFT
            try nftContract.mintCertificate(
                request.student,
                request.courseId,
                request.courseName,
                request.timestamp
            ) returns (uint256 tokenId) {
                request.success = true;
                emit RequestFulfilled(requestId, request.student, request.courseId, true, tokenId);
            } catch {
                request.success = false;
                emit RequestFulfilled(requestId, request.student, request.courseId, false, 0);
            }
        } else {
            // 学生未完成课程
            request.success = false;
            emit RequestFulfilled(requestId, request.student, request.courseId, false, 0);
        }
    }

    // ==================== 批量请求 ====================

    /**
     * @dev 批量请求多个学生的课程完成验证
     * @param students 学生地址数组
     * @param courseIds 课程 ID 数组
     * @param courseNames 课程名称数组
     * @return requestIds 请求 ID 数组
     */
    function batchRequestCourseCompletion(
        address[] calldata students,
        uint256[] calldata courseIds,
        string[] calldata courseNames
    ) external returns (bytes32[] memory requestIds) {
        uint256 length = students.length;
        require(
            length == courseIds.length && length == courseNames.length,
            "Array lengths mismatch"
        );

        requestIds = new bytes32[](length);

        for (uint256 i = 0; i < length; i++) {
            requestIds[i] = this.requestCourseCompletion(
                students[i],
                courseIds[i],
                courseNames[i]
            );
        }

        return requestIds;
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取请求详情
     * @param requestId 请求 ID
     */
    function getRequest(bytes32 requestId)
        external
        view
        returns (CourseCompletionRequest memory)
    {
        return requests[requestId];
    }

    /**
     * @dev 获取学生某课程的请求 ID
     * @param student 学生地址
     * @param courseId 课程 ID
     */
    function getStudentCourseRequestId(address student, uint256 courseId)
        external
        view
        returns (bytes32)
    {
        return studentCourseRequests[student][courseId];
    }

    /**
     * @dev 检查学生是否有待处理的请求
     * @param student 学生地址
     * @param courseId 课程 ID
     */
    function hasPendingRequest(address student, uint256 courseId)
        external
        view
        returns (bool)
    {
        bytes32 requestId = studentCourseRequests[student][courseId];
        if (requestId == bytes32(0)) return false;
        return !requests[requestId].fulfilled;
    }

    // ==================== 管理员功能 ====================

    /**
     * @dev 更新 JavaScript 源代码
     * @param newSource 新的源代码
     */
    function updateSource(string calldata newSource) external onlyOwner {
        require(bytes(newSource).length > 0, "Empty source code");
        source = newSource;
        emit SourceCodeUpdated(newSource);
    }

    /**
     * @dev 更新 Chainlink Functions 配置
     * @param _subscriptionId 新的订阅 ID
     * @param _gasLimit 新的 gas 限制
     * @param _donId 新的 DON ID
     */
    function updateConfig(
        uint64 _subscriptionId,
        uint32 _gasLimit,
        bytes32 _donId
    ) external onlyOwner {
        subscriptionId = _subscriptionId;
        gasLimit = _gasLimit;
        donId = _donId;
        emit ConfigUpdated(_subscriptionId, _gasLimit, _donId);
    }

    /**
     * @dev 更新 NFT 合约地址
     * @param _nftContract 新的 NFT 合约地址
     */
    function updateNFTContract(address _nftContract) external onlyOwner {
        if (_nftContract == address(0)) revert InvalidAddress();
        nftContract = SimpleYDNFT(_nftContract);
    }

    /**
     * @dev 转移所有权
     * @param newOwner 新的所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        owner = newOwner;
    }

    // ==================== 工具函数 ====================

    /**
     * @dev 将地址转换为字符串（小写，带 0x 前缀）
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';

        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(uint160(addr) >> (160 - 8 - i * 8)) >> 4];
            str[3 + i * 2] = alphabet[uint8(uint160(addr) >> (160 - 8 - i * 8)) & 0x0f];
        }

        return string(str);
    }

    /**
     * @dev 将 uint256 转换为字符串
     */
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }

        return string(buffer);
    }
}
