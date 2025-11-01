// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CourseManage
 * @dev 课程管理合约
 * @notice 设计理念:
 *   1. 课程ID由后端生成(UUID等)
 *   2. 合约只存储核心不可篡改数据
 *   3. 购买时YD代币直接转给讲师(90%)和平台(10%)
 *   5. 流程: 后端创建课程 → 前端调用合约上链 → 学生购买
 */
contract CourseManage is ReentrancyGuard {
    // ==================== 核心数据结构 ====================

    /**
     * @dev 课程所有权信息(不可篡改)
     */
    struct CourseOwnership {
        address instructor; // 讲师地址
        uint256 price; // 课程价格
        bool exists; // 是否存在
    }

    /**
     * @dev 购买记录(不可篡改)
     */
    struct PurchaseRecord {
        uint256 timestamp; // 购买时间
        uint256 paidPrice; // 实际支付价格
        bool purchased; // 是否已购买
    }

    // ==================== 状态变量 ====================

    IERC20 public immutable ydToken;
    address public platformAddress;

    // 费率配置
    uint256 public constant INSTRUCTOR_RATE = 90; // 讲师分成90%
    uint256 public constant PLATFORM_RATE = 10; // 平台分成10%

    // 核心映射(链上数据)
    mapping(string => CourseOwnership) public courses; // courseId => 课程所有权
    mapping(address => mapping(string => PurchaseRecord)) public purchases; // student => courseId => 购买记录

    // ==================== 事件 ====================

    event CourseRegistered(
        string indexed courseId,
        address indexed instructor,
        uint256 price,
        uint256 timestamp
    );

    event CoursePurchased(
        string indexed courseId,
        address indexed student,
        address indexed instructor,
        uint256 price,
        uint256 timestamp
    );

    // ==================== 错误定义 ====================

    error InvalidAddress();
    error InvalidPrice();
    error CourseAlreadyExists();
    error CourseNotExist();
    error AlreadyPurchased();
    error InsufficientBalance();
    error OnlyPlatform();

    // ==================== 修饰符 ====================

    modifier onlyPlatform() {
        if (msg.sender != platformAddress) revert OnlyPlatform();
        _;
    }

    modifier courseExists(string memory courseId) {
        if (!courses[courseId].exists) revert CourseNotExist();
        _;
    }

    // ==================== 构造函数 ====================

    constructor(address _ydToken, address _platformAddress) {
        if (_ydToken == address(0) || _platformAddress == address(0)) {
            revert InvalidAddress();
        }

        ydToken = IERC20(_ydToken);
        platformAddress = _platformAddress;
    }

    // ==================== 核心功能 ====================

    /**
     * @dev 注册课程到链上(课程ID由后端生成)
     * @param courseId 后端生成的课程ID(如UUID)
     * @param price 课程价格
     *
     * 流程:
     * 1. 前端调用后端API创建课程 → 返回courseId
     * 2. 前端调用此函数,将课程数据上链
     */
    function registerCourse(string calldata courseId, uint256 price) external {
        if (courses[courseId].exists) revert CourseAlreadyExists();
        if (price == 0) revert InvalidPrice();

        courses[courseId] = CourseOwnership({
            instructor: msg.sender,
            price: price,
            exists: true
        });

        emit CourseRegistered(courseId, msg.sender, price, block.timestamp);
    }

    /**
     * @dev 购买课程
     * @param courseId 课程ID
     * @notice 购买流程:
     *   1. 学生需先授权合约使用YD代币
     *   2. 合约直接将代币转给讲师(90%)和平台(10%)
     *   3. 合约本身不持有资金
     */
    function purchaseCourse(
        string calldata courseId
    ) external nonReentrant courseExists(courseId) {
        CourseOwnership storage course = courses[courseId];
        PurchaseRecord storage purchase = purchases[msg.sender][courseId];

        // 检查
        if (purchase.purchased) revert AlreadyPurchased();
        if (course.instructor == msg.sender)
            revert("Cannot purchase own course");
        if (ydToken.balanceOf(msg.sender) < course.price)
            revert InsufficientBalance();

        // 记录购买
        purchases[msg.sender][courseId] = PurchaseRecord({
            timestamp: block.timestamp,
            paidPrice: course.price,
            purchased: true
        });

        // 计算分成
        uint256 instructorAmount = (course.price * INSTRUCTOR_RATE) / 100;
        uint256 platformAmount = course.price - instructorAmount;

        // 直接转账给讲师和平台
        require(
            ydToken.transferFrom(
                msg.sender,
                course.instructor,
                instructorAmount
            ),
            "Instructor transfer failed"
        );
        require(
            ydToken.transferFrom(msg.sender, platformAddress, platformAmount),
            "Platform transfer failed"
        );

        emit CoursePurchased(
            courseId,
            msg.sender,
            course.instructor,
            course.price,
            block.timestamp
        );
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 检查学生是否有访问权限
     */
    function hasAccess(
        address student,
        string memory courseId
    ) external view courseExists(courseId) returns (bool) {
        return purchases[student][courseId].purchased;
    }

    /**
     * @dev 获取课程信息
     */
    function getCourse(
        string memory courseId
    ) external view courseExists(courseId) returns (CourseOwnership memory) {
        return courses[courseId];
    }

    /**
     * @dev 获取购买记录
     */
    function getPurchaseRecord(
        address student,
        string memory courseId
    ) external view returns (PurchaseRecord memory) {
        return purchases[student][courseId];
    }

    // ==================== 平台管理 ====================

    /**
     * @dev 更新平台地址(仅平台)
     */
    function updatePlatformAddress(address newAddress) external onlyPlatform {
        if (newAddress == address(0)) revert InvalidAddress();
        platformAddress = newAddress;
    }
}
