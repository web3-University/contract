// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {YiDengToken} from "../YiDengToken.sol";

contract YiDengTokenTest is Test {
    YiDengToken public token;
    address public owner;
    address public user1;
    address public user2;

    // 事件声明（用于测试事件触发）
    event ExchangeRateUpdated(uint256 newRate);
    event TokenExchanged(
        address indexed user,
        uint256 ethAmount,
        uint256 ydAmount
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署合约
        token = new YiDengToken(owner);

        // 给测试用户分配一些 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // ============ 基础功能测试 ============

    function test_InitialState() public view {
        assertEq(token.name(), "YiDengToken");
        assertEq(token.symbol(), "YD");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(token.exchangeRate(), 0);
    }

    function test_Mint() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, mintAmount);

        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function test_MintOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000 * 10 ** 18);
    }

    function test_Burn() public {
        uint256 mintAmount = 1000 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function test_Transfer() public {
        uint256 mintAmount = 1000 * 10 ** 18;
        uint256 transferAmount = 300 * 10 ** 18;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.transfer(user2, transferAmount);

        assertEq(token.balanceOf(user1), mintAmount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    // ============ 兑换比例测试 ============

    function test_SetExchangeRate() public {
        uint256 newRate = 1000;

        vm.expectEmit(false, false, false, true);
        emit ExchangeRateUpdated(newRate);

        token.setExchangeRate(newRate);

        assertEq(token.exchangeRate(), newRate);
    }

    function test_SetExchangeRateOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setExchangeRate(1000);
    }

    function test_SetExchangeRateZeroReverts() public {
        vm.expectRevert("Exchange rate must be greater than 0");
        token.setExchangeRate(0);
    }

    // ============ ETH 兑换代币测试 ============

    function test_ExchangeETHForTokens() public {
        uint256 exchangeRate = 1000;
        uint256 ethAmount = 1 ether;
        uint256 expectedYD = ethAmount * exchangeRate;

        token.setExchangeRate(exchangeRate);

        vm.expectEmit(true, false, false, true);
        emit TokenExchanged(user1, ethAmount, expectedYD);

        vm.prank(user1);
        token.exchangeETHForTokens{value: ethAmount}();

        assertEq(token.balanceOf(user1), expectedYD);
        assertEq(address(token).balance, ethAmount);
    }

    function test_ExchangeETHForTokensMultipleTimes() public {
        uint256 exchangeRate = 500;
        token.setExchangeRate(exchangeRate);

        // 第一次兑换
        vm.prank(user1);
        token.exchangeETHForTokens{value: 1 ether}();

        // 第二次兑换
        vm.prank(user1);
        token.exchangeETHForTokens{value: 2 ether}();

        assertEq(token.balanceOf(user1), 1500 * 10 ** 18);
        assertEq(address(token).balance, 3 ether);
    }

    function test_ExchangeETHForTokensZeroETHReverts() public {
        token.setExchangeRate(1000);

        vm.prank(user1);
        vm.expectRevert("ETH amount must be greater than 0");
        token.exchangeETHForTokens{value: 0}();
    }

    function test_ExchangeETHForTokensNoRateSetReverts() public {
        vm.prank(user1);
        vm.expectRevert("Exchange rate not set");
        token.exchangeETHForTokens{value: 1 ether}();
    }

    function test_ExchangeETHForTokensDifferentUsers() public {
        uint256 exchangeRate = 2000;
        token.setExchangeRate(exchangeRate);

        // user1 兑换
        vm.prank(user1);
        token.exchangeETHForTokens{value: 0.5 ether}();

        // user2 兑换
        vm.prank(user2);
        token.exchangeETHForTokens{value: 1 ether}();

        assertEq(token.balanceOf(user1), 1000 * 10 ** 18);
        assertEq(token.balanceOf(user2), 2000 * 10 ** 18);
        assertEq(address(token).balance, 1.5 ether);
    }

    // ============ receive 函数测试 ============

    function test_ReceiveTriggersExchange() public {
        uint256 exchangeRate = 1000;
        uint256 ethAmount = 1 ether;
        uint256 expectedYD = ethAmount * exchangeRate;

        token.setExchangeRate(exchangeRate);

        vm.prank(user1);
        (bool success, ) = address(token).call{value: ethAmount}("");
        require(success, "Transfer failed");

        assertEq(token.balanceOf(user1), expectedYD);
        assertEq(address(token).balance, ethAmount);
    }

    function test_ReceiveWithZeroETHReverts() public {
        token.setExchangeRate(1000);

        vm.prank(user1);
        vm.expectRevert("ETH amount must be greater than 0");
        (bool success, ) = address(token).call{value: 0}("");
        require(!success, "Should have reverted");
    }

    // ============ 边界条件测试 ============

    function testFuzz_ExchangeETHForTokens(uint256 ethAmount) public {
        // 限制测试范围
        vm.assume(ethAmount > 0 && ethAmount <= 100 ether);

        uint256 exchangeRate = 1000;
        token.setExchangeRate(exchangeRate);

        // 给 user1 足够的 ETH
        vm.deal(user1, ethAmount);

        vm.prank(user1);
        token.exchangeETHForTokens{value: ethAmount}();

        assertEq(token.balanceOf(user1), ethAmount * exchangeRate);
        assertEq(address(token).balance, ethAmount);
    }

    function testFuzz_SetExchangeRate(uint256 rate) public {
        vm.assume(rate > 0 && rate < type(uint128).max); // 避免溢出

        token.setExchangeRate(rate);
        assertEq(token.exchangeRate(), rate);
    }

    function test_LargeAmountExchange() public {
        uint256 exchangeRate = 1000000; // 100万倍
        token.setExchangeRate(exchangeRate);

        vm.prank(user1);
        token.exchangeETHForTokens{value: 1 ether}();

        assertEq(token.balanceOf(user1), 1 ether * exchangeRate);
    }

    function test_SmallAmountExchange() public {
        uint256 exchangeRate = 1;
        token.setExchangeRate(exchangeRate);

        vm.prank(user1);
        token.exchangeETHForTokens{value: 1 wei}();

        assertEq(token.balanceOf(user1), 1);
    }

    // ============ 集成测试 ============

    function test_CompleteWorkflow() public {
        // 1. 设置兑换比例
        token.setExchangeRate(1000);

        // 2. user1 兑换代币
        vm.prank(user1);
        token.exchangeETHForTokens{value: 1 ether}();

        // 3. user1 转账给 user2
        vm.prank(user1);
        token.transfer(user2, 500 * 10 ** 18);

        // 4. user2 销毁部分代币
        vm.prank(user2);
        token.burn(200 * 10 ** 18);

        // 5. owner 铸造代币给 user2
        token.mint(user2, 300 * 10 ** 18);

        // 验证最终状态
        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.balanceOf(user2), 600 * 10 ** 18);
        assertEq(token.totalSupply(), 1100 * 10 ** 18);
    }
}
