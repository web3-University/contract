// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ICourseContract.sol";

/**
 * @title MockCourseContract
 * @dev 用于测试的课程合约 Mock
 */
contract MockCourseContract is ICourseContract {

    // 课程数据存储
    mapping(uint256 => Course) private courses;
    mapping(uint256 => uint256) private courseStudentCounts;
    uint256 private courseIdCounter;

    /**
     * @dev 创建测试课程
     */
    function createMockCourse(
        string memory name,
        string memory description,
        address creator,
        uint256 price
    ) external returns (uint256) {
        courseIdCounter++;
        uint256 courseId = courseIdCounter;

        courses[courseId] = Course({
            id: courseId,
            name: name,
            description: description,
            creator: creator,
            price: price,
            isActive: true,
            createdAt: block.timestamp
        });

        courseStudentCounts[courseId] = 0;

        return courseId;
    }

    /**
     * @dev 设置课程学生数量 (用于测试)
     */
    function setStudentCount(uint256 courseId, uint256 count) external {
        courseStudentCounts[courseId] = count;
    }

    /**
     * @dev 设置课程状态
     */
    function setCourseActive(uint256 courseId, bool isActive) external {
        courses[courseId].isActive = isActive;
    }

    // ==================== ICourseContract 接口实现 ====================

    function getCourse(uint256 courseId) external view override returns (Course memory) {
        return courses[courseId];
    }

    function getCourseStudentCount(uint256 courseId) external view override returns (uint256) {
        return courseStudentCounts[courseId];
    }

    function isCourseActive(uint256 courseId) external view override returns (bool) {
        return courses[courseId].isActive;
    }
}
