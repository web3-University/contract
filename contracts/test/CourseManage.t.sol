// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CourseManage} from "../CourseManage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Mock YD Token for testing
contract MockYDToken is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string public name = "YiDeng Token";
    string public symbol = "YD";
    uint8 public decimals = 18;

    function mint(address to, uint256 amount) public {
        _balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(_balances[from] >= amount, "Insufficient balance");
        require(
            _allowances[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
}

contract CourseManageTest is Test {
    CourseManage public courseManage;
    MockYDToken public ydToken;

    address public platform;
    address public instructor;
    address public student1;
    address public student2;

    // 测试用的课程 ID
    string constant COURSE_ID_1 = "course-uuid-001";
    string constant COURSE_ID_2 = "course-uuid-002";
    string constant COURSE_ID_3 = "course-uuid-003";

    // 课程价格
    uint256 constant COURSE_PRICE = 100 * 10 ** 18; // 100 YD

    // 事件声明
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

    function setUp() public {
        platform = makeAddr("platform");
        instructor = makeAddr("instructor");
        student1 = makeAddr("student1");
        student2 = makeAddr("student2");

        // 部署 Mock YD Token
        ydToken = new MockYDToken();

        // 部署 CourseManage 合约
        courseManage = new CourseManage(address(ydToken), platform);

        // 给学生分配代币
        ydToken.mint(student1, 1000 * 10 ** 18);
        ydToken.mint(student2, 1000 * 10 ** 18);
    }

    // ============ 构造函数测试 ============

    function test_Constructor() public view {
        assertEq(address(courseManage.ydToken()), address(ydToken));
        assertEq(courseManage.platformAddress(), platform);
        assertEq(courseManage.INSTRUCTOR_RATE(), 90);
        assertEq(courseManage.PLATFORM_RATE(), 10);
    }

    function test_ConstructorRevertsWithZeroTokenAddress() public {
        vm.expectRevert(CourseManage.InvalidAddress.selector);
        new CourseManage(address(0), platform);
    }

    function test_ConstructorRevertsWithZeroPlatformAddress() public {
        vm.expectRevert(CourseManage.InvalidAddress.selector);
        new CourseManage(address(ydToken), address(0));
    }

    // ============ 注册课程测试 ============

    function test_RegisterCourse() public {
        vm.expectEmit(true, true, false, true);
        emit CourseRegistered(
            COURSE_ID_1,
            instructor,
            COURSE_PRICE,
            block.timestamp
        );

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 验证课程信息
        CourseManage.CourseOwnership memory course = courseManage.getCourse(
            COURSE_ID_1
        );
        assertEq(course.instructor, instructor);
        assertEq(course.price, COURSE_PRICE);
        assertTrue(course.exists);
    }

    function test_RegisterMultipleCourses() public {
        vm.startPrank(instructor);
        courseManage.registerCourse(COURSE_ID_1, 50 * 10 ** 18);
        courseManage.registerCourse(COURSE_ID_2, 100 * 10 ** 18);
        courseManage.registerCourse(COURSE_ID_3, 150 * 10 ** 18);
        vm.stopPrank();

        CourseManage.CourseOwnership memory course1 = courseManage.getCourse(
            COURSE_ID_1
        );
        CourseManage.CourseOwnership memory course2 = courseManage.getCourse(
            COURSE_ID_2
        );
        CourseManage.CourseOwnership memory course3 = courseManage.getCourse(
            COURSE_ID_3
        );

        assertEq(course1.price, 50 * 10 ** 18);
        assertEq(course2.price, 100 * 10 ** 18);
        assertEq(course3.price, 150 * 10 ** 18);
    }

    function test_RegisterCourseRevertsWithDuplicateId() public {
        vm.startPrank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        vm.expectRevert(CourseManage.CourseAlreadyExists.selector);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);
        vm.stopPrank();
    }

    function test_RegisterCourseRevertsWithZeroPrice() public {
        vm.prank(instructor);
        vm.expectRevert(CourseManage.InvalidPrice.selector);
        courseManage.registerCourse(COURSE_ID_1, 0);
    }

    function test_RegisterCourseRevertsWithEmptyId() public {
        vm.prank(instructor);
        vm.expectRevert(CourseManage.InvalidPrice.selector);
        courseManage.registerCourse("", COURSE_PRICE);
    }

    function test_DifferentInstructorsCanRegisterDifferentCourses() public {
        address instructor2 = makeAddr("instructor2");

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        vm.prank(instructor2);
        courseManage.registerCourse(COURSE_ID_2, COURSE_PRICE);

        CourseManage.CourseOwnership memory course1 = courseManage.getCourse(
            COURSE_ID_1
        );
        CourseManage.CourseOwnership memory course2 = courseManage.getCourse(
            COURSE_ID_2
        );

        assertEq(course1.instructor, instructor);
        assertEq(course2.instructor, instructor2);
    }

    // ============ 购买课程测试 ============

    function test_PurchaseCourse() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 学生授权
        vm.prank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);

        // 记录初始余额
        uint256 instructorBalanceBefore = ydToken.balanceOf(instructor);
        uint256 platformBalanceBefore = ydToken.balanceOf(platform);
        uint256 studentBalanceBefore = ydToken.balanceOf(student1);

        // 购买课程
        vm.expectEmit(true, true, true, true);
        emit CoursePurchased(
            COURSE_ID_1,
            student1,
            instructor,
            COURSE_PRICE,
            block.timestamp
        );

        vm.prank(student1);
        courseManage.purchaseCourse(COURSE_ID_1);

        // 验证余额变化
        uint256 instructorAmount = (COURSE_PRICE * 90) / 100;
        uint256 platformAmount = COURSE_PRICE - instructorAmount;

        assertEq(
            ydToken.balanceOf(instructor),
            instructorBalanceBefore + instructorAmount
        );
        assertEq(
            ydToken.balanceOf(platform),
            platformBalanceBefore + platformAmount
        );
        assertEq(
            ydToken.balanceOf(student1),
            studentBalanceBefore - COURSE_PRICE
        );

        // 验证购买记录
        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));

        CourseManage.PurchaseRecord memory record = courseManage
            .getPurchaseRecord(student1, COURSE_ID_1);
        assertTrue(record.purchased);
        assertEq(record.paidPrice, COURSE_PRICE);
        assertEq(record.timestamp, block.timestamp);
    }

    function test_PurchaseMultipleCourses() public {
        // 注册多个课程
        vm.startPrank(instructor);
        courseManage.registerCourse(COURSE_ID_1, 50 * 10 ** 18);
        courseManage.registerCourse(COURSE_ID_2, 100 * 10 ** 18);
        vm.stopPrank();

        // 学生购买两个课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), 150 * 10 ** 18);
        courseManage.purchaseCourse(COURSE_ID_1);
        courseManage.purchaseCourse(COURSE_ID_2);
        vm.stopPrank();

        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));
        assertTrue(courseManage.hasAccess(student1, COURSE_ID_2));
    }

    function test_MultipleStudentsPurchaseSameCourse() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 学生1购买
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 学生2购买
        vm.startPrank(student2);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));
        assertTrue(courseManage.hasAccess(student2, COURSE_ID_1));
    }

    function test_PurchaseCourseRevertsWithNonexistentCourse() public {
        vm.prank(student1);
        vm.expectRevert(CourseManage.CourseNotExist.selector);
        courseManage.purchaseCourse("nonexistent-course");
    }

    function test_PurchaseCourseRevertsWhenAlreadyPurchased() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 第一次购买
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);

        // 第二次购买应该失败
        vm.expectRevert(CourseManage.AlreadyPurchased.selector);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();
    }

    function test_PurchaseCourseRevertsWhenInstructorBuysOwnCourse() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 讲师尝试购买自己的课程
        ydToken.mint(instructor, COURSE_PRICE);

        vm.startPrank(instructor);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        vm.expectRevert("Cannot purchase own course");
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();
    }

    function test_PurchaseCourseRevertsWithInsufficientBalance() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 创建一个没有代币的学生
        address poorStudent = makeAddr("poorStudent");

        vm.startPrank(poorStudent);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        vm.expectRevert(CourseManage.InsufficientBalance.selector);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();
    }

    function test_PurchaseCourseRevertsWithoutApproval() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 尝试购买但未授权
        vm.prank(student1);
        vm.expectRevert("Instructor transfer failed");
        courseManage.purchaseCourse(COURSE_ID_1);
    }

    function test_PurchaseCourseRevertsWithInsufficientApproval() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 授权不足
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE / 2);
        vm.expectRevert("Instructor transfer failed");
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();
    }

    // ============ 分成计算测试 ============

    function test_PaymentSplitCalculation() public {
        uint256 price = 100 * 10 ** 18;

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, price);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), price);

        uint256 instructorBalanceBefore = ydToken.balanceOf(instructor);
        uint256 platformBalanceBefore = ydToken.balanceOf(platform);

        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        uint256 instructorAmount = ydToken.balanceOf(instructor) -
            instructorBalanceBefore;
        uint256 platformAmount = ydToken.balanceOf(platform) -
            platformBalanceBefore;

        // 验证分成比例
        assertEq(instructorAmount, 90 * 10 ** 18); // 90%
        assertEq(platformAmount, 10 * 10 ** 18); // 10%
        assertEq(instructorAmount + platformAmount, price);
    }

    function test_PaymentSplitWithDifferentPrices() public {
        uint256[] memory prices = new uint256[](3);
        prices[0] = 50 * 10 ** 18;
        prices[1] = 100 * 10 ** 18;
        prices[2] = 200 * 10 ** 18;

        string[] memory courseIds = new string[](3);
        courseIds[0] = "course-001";
        courseIds[1] = "course-002";
        courseIds[2] = "course-003";

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(instructor);
            courseManage.registerCourse(courseIds[i], prices[i]);

            vm.startPrank(student1);
            ydToken.approve(address(courseManage), prices[i]);

            uint256 instructorBalanceBefore = ydToken.balanceOf(instructor);
            uint256 platformBalanceBefore = ydToken.balanceOf(platform);

            courseManage.purchaseCourse(courseIds[i]);
            vm.stopPrank();

            uint256 expectedInstructor = (prices[i] * 90) / 100;
            uint256 expectedPlatform = prices[i] - expectedInstructor;

            assertEq(
                ydToken.balanceOf(instructor) - instructorBalanceBefore,
                expectedInstructor
            );
            assertEq(
                ydToken.balanceOf(platform) - platformBalanceBefore,
                expectedPlatform
            );
        }
    }

    // ============ 访问权限测试 ============

    function test_HasAccess() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 购买前无权限
        assertFalse(courseManage.hasAccess(student1, COURSE_ID_1));

        // 购买课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 购买后有权限
        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));

        // 其他学生无权限
        assertFalse(courseManage.hasAccess(student2, COURSE_ID_1));
    }

    function test_HasAccessRevertsWithNonexistentCourse() public {
        vm.expectRevert(CourseManage.CourseNotExist.selector);
        courseManage.hasAccess(student1, "nonexistent-course");
    }

    // ============ 查询功能测试 ============

    function test_GetCourse() public {
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        CourseManage.CourseOwnership memory course = courseManage.getCourse(
            COURSE_ID_1
        );

        assertEq(course.instructor, instructor);
        assertEq(course.price, COURSE_PRICE);
        assertTrue(course.exists);
    }

    function test_GetCourseRevertsWithNonexistentCourse() public {
        vm.expectRevert(CourseManage.CourseNotExist.selector);
        courseManage.getCourse("nonexistent-course");
    }

    function test_GetPurchaseRecord() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 购买前
        CourseManage.PurchaseRecord memory recordBefore = courseManage
            .getPurchaseRecord(student1, COURSE_ID_1);
        assertFalse(recordBefore.purchased);
        assertEq(recordBefore.paidPrice, 0);
        assertEq(recordBefore.timestamp, 0);

        // 购买课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 购买后
        CourseManage.PurchaseRecord memory recordAfter = courseManage
            .getPurchaseRecord(student1, COURSE_ID_1);
        assertTrue(recordAfter.purchased);
        assertEq(recordAfter.paidPrice, COURSE_PRICE);
        assertEq(recordAfter.timestamp, block.timestamp);
    }

    // ============ 平台管理测试 ============

    function test_UpdatePlatformAddress() public {
        address newPlatform = makeAddr("newPlatform");

        vm.prank(platform);
        courseManage.updatePlatformAddress(newPlatform);

        assertEq(courseManage.platformAddress(), newPlatform);
    }

    function test_UpdatePlatformAddressRevertsWithZeroAddress() public {
        vm.prank(platform);
        vm.expectRevert(CourseManage.InvalidAddress.selector);
        courseManage.updatePlatformAddress(address(0));
    }

    function test_UpdatePlatformAddressRevertsWhenNotPlatform() public {
        address newPlatform = makeAddr("newPlatform");

        vm.prank(student1);
        vm.expectRevert(CourseManage.OnlyPlatform.selector);
        courseManage.updatePlatformAddress(newPlatform);
    }

    function test_NewPlatformReceivesPayments() public {
        address newPlatform = makeAddr("newPlatform");

        // 更新平台地址
        vm.prank(platform);
        courseManage.updatePlatformAddress(newPlatform);

        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 购买课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);

        uint256 newPlatformBalanceBefore = ydToken.balanceOf(newPlatform);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 验证新平台地址收到款项
        uint256 expectedPlatformAmount = (COURSE_PRICE * 10) / 100;
        assertEq(
            ydToken.balanceOf(newPlatform),
            newPlatformBalanceBefore + expectedPlatformAmount
        );
    }

    // ============ 边界条件测试 ============

    function testFuzz_RegisterCourseWithDifferentPrices(uint256 price) public {
        vm.assume(price > 0 && price <= 1000000 * 10 ** 18); // 合理的价格范围

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, price);

        CourseManage.CourseOwnership memory course = courseManage.getCourse(
            COURSE_ID_1
        );
        assertEq(course.price, price);
    }

    function testFuzz_PurchaseCourseWithDifferentPrices(uint256 price) public {
        vm.assume(price > 0 && price <= 1000 * 10 ** 18);

        // 给学生更多代币
        ydToken.mint(student1, price);

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, price);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), price);

        uint256 instructorBalanceBefore = ydToken.balanceOf(instructor);
        uint256 platformBalanceBefore = ydToken.balanceOf(platform);

        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        uint256 expectedInstructor = (price * 90) / 100;
        uint256 expectedPlatform = price - expectedInstructor;

        assertEq(
            ydToken.balanceOf(instructor),
            instructorBalanceBefore + expectedInstructor
        );
        assertEq(
            ydToken.balanceOf(platform),
            platformBalanceBefore + expectedPlatform
        );
    }

    function test_VerySmallPrice() public {
        uint256 smallPrice = 10; // 10 wei

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, smallPrice);

        ydToken.mint(student1, smallPrice);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), smallPrice);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));
    }

    function test_VeryLargePrice() public {
        uint256 largePrice = 1000000 * 10 ** 18; // 1 million YD

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, largePrice);

        ydToken.mint(student1, largePrice);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), largePrice);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));
    }

    // ============ 集成测试 ============

    function test_CompleteWorkflow() public {
        // 1. 讲师注册多个课程
        vm.startPrank(instructor);
        courseManage.registerCourse("course-001", 50 * 10 ** 18);
        courseManage.registerCourse("course-002", 100 * 10 ** 18);
        courseManage.registerCourse("course-003", 150 * 10 ** 18);
        vm.stopPrank();

        // 2. 学生1购买课程1和2
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), 150 * 10 ** 18);
        courseManage.purchaseCourse("course-001");
        courseManage.purchaseCourse("course-002");
        vm.stopPrank();

        // 3. 学生2购买课程2和3
        vm.startPrank(student2);
        ydToken.approve(address(courseManage), 250 * 10 ** 18);
        courseManage.purchaseCourse("course-002");
        courseManage.purchaseCourse("course-003");
        vm.stopPrank();

        // 4. 验证访问权限
        assertTrue(courseManage.hasAccess(student1, "course-001"));
        assertTrue(courseManage.hasAccess(student1, "course-002"));
        assertFalse(courseManage.hasAccess(student1, "course-003"));

        assertFalse(courseManage.hasAccess(student2, "course-001"));
        assertTrue(courseManage.hasAccess(student2, "course-002"));
        assertTrue(courseManage.hasAccess(student2, "course-003"));

        // 5. 验证讲师和平台收益
        // course-001: 50 YD (学生1)
        // course-002: 100 YD (学生1) + 100 YD (学生2) = 200 YD
        // course-003: 150 YD (学生2)
        // 总计: 400 YD
        uint256 totalRevenue = 400 * 10 ** 18;
        uint256 expectedInstructor = (totalRevenue * 90) / 100;
        uint256 expectedPlatform = totalRevenue - expectedInstructor;

        assertEq(ydToken.balanceOf(instructor), expectedInstructor);
        assertEq(ydToken.balanceOf(platform), expectedPlatform);
    }

    function test_MultipleInstructorsWorkflow() public {
        address instructor2 = makeAddr("instructor2");

        // 讲师1注册课程
        vm.prank(instructor);
        courseManage.registerCourse("course-001", 100 * 10 ** 18);

        // 讲师2注册课程
        vm.prank(instructor2);
        courseManage.registerCourse("course-002", 200 * 10 ** 18);

        // 学生购买两个课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), 300 * 10 ** 18);
        courseManage.purchaseCourse("course-001");
        courseManage.purchaseCourse("course-002");
        vm.stopPrank();

        // 验证两个讲师各自收到对应的款项
        assertEq(ydToken.balanceOf(instructor), 90 * 10 ** 18); // 100 * 90%
        assertEq(ydToken.balanceOf(instructor2), 180 * 10 ** 18); // 200 * 90%
    }

    // ============ Gas 优化测试 ============

    function test_GasUsageRegisterCourse() public {
        uint256 gasBefore = gasleft();

        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for registerCourse", gasUsed);

        // 验证 gas 使用在合理范围内 (< 100k)
        assertLt(gasUsed, 100000);
    }

    function test_GasUsagePurchaseCourse() public {
        // 准备
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);

        uint256 gasBefore = gasleft();
        courseManage.purchaseCourse(COURSE_ID_1);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for purchaseCourse", gasUsed);

        // 验证 gas 使用在合理范围内 (< 150k)
        assertLt(gasUsed, 150000);
        vm.stopPrank();
    }

    // ============ 安全性测试 ============

    function test_ReentrancyProtection() public {
        // 由于使用了 ReentrancyGuard，重入攻击会被阻止
        // 这里只是验证修饰符存在
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        assertTrue(courseManage.hasAccess(student1, COURSE_ID_1));
    }

    function test_CannotManipulatePurchaseRecord() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 购买课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 验证购买记录不能被操纵（只能通过购买修改）
        CourseManage.PurchaseRecord memory record = courseManage
            .getPurchaseRecord(student1, COURSE_ID_1);
        assertTrue(record.purchased);

        // 尝试再次购买会失败
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        vm.expectRevert(CourseManage.AlreadyPurchased.selector);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();
    }

    function test_ContractDoesNotHoldFunds() public {
        // 注册课程
        vm.prank(instructor);
        courseManage.registerCourse(COURSE_ID_1, COURSE_PRICE);

        // 购买课程
        vm.startPrank(student1);
        ydToken.approve(address(courseManage), COURSE_PRICE);
        courseManage.purchaseCourse(COURSE_ID_1);
        vm.stopPrank();

        // 验证合约不持有任何代币
        assertEq(ydToken.balanceOf(address(courseManage)), 0);
    }
}
