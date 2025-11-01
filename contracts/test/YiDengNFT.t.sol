// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {YiDengNFT} from "../YiDengNFT.sol";

contract YiDengNFTTest is Test {
    YiDengNFT public nft;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // 事件声明（用于测试事件触发）
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // 测试用的 URI
    string constant TEST_URI_1 = "ipfs://QmTest1";
    string constant TEST_URI_2 = "ipfs://QmTest2";
    string constant TEST_URI_3 = "ipfs://QmTest3";

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // 部署合约
        nft = new YiDengNFT(owner);
    }

    // ============ 基础功能测试 ============

    function test_InitialState() public view {
        assertEq(nft.name(), "YiDengNFT");
        assertEq(nft.symbol(), "YDNFT");
        assertEq(nft.owner(), owner);
    }

    function test_SupportsInterface() public view {
        // ERC721
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(nft.supportsInterface(0x5b5e139f));
        // ERC165
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    // ============ 铸造功能测试 ============

    function test_SafeMint() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, 0);

        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.tokenURI(tokenId), TEST_URI_1);
        assertEq(nft.balanceOf(user1), 1);
    }

    function test_SafeMintMultiple() public {
        uint256 tokenId1 = nft.safeMint(user1, TEST_URI_1);
        uint256 tokenId2 = nft.safeMint(user2, TEST_URI_2);
        uint256 tokenId3 = nft.safeMint(user1, TEST_URI_3);

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);

        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.balanceOf(user2), 1);

        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.ownerOf(2), user1);

        assertEq(nft.tokenURI(0), TEST_URI_1);
        assertEq(nft.tokenURI(1), TEST_URI_2);
        assertEq(nft.tokenURI(2), TEST_URI_3);
    }

    function test_SafeMintOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.safeMint(user1, TEST_URI_1);
    }

    function test_SafeMintToContract() public {
        // 创建一个可以接收 NFT 的合约
        NFTReceiver receiver = new NFTReceiver();

        uint256 tokenId = nft.safeMint(address(receiver), TEST_URI_1);

        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function test_SafeMintToNonReceiverReverts() public {
        // 创建一个不能接收 NFT 的合约
        NonNFTReceiver nonReceiver = new NonNFTReceiver();

        vm.expectRevert();
        nft.safeMint(address(nonReceiver), TEST_URI_1);
    }

    // ============ 转账功能测试 ============

    function test_TransferFrom() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_SafeTransferFrom() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_SafeTransferFromWithData() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, tokenId, "");

        assertEq(nft.ownerOf(tokenId), user2);
    }

    function test_TransferFromNotOwnerReverts() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user2);
        vm.expectRevert();
        nft.transferFrom(user1, user2, tokenId);
    }

    function test_TransferFromNonexistentTokenReverts() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.transferFrom(user1, user2, 999);
    }

    // ============ 授权功能测试 ============

    function test_Approve() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.expectEmit(true, true, true, true);
        emit Approval(user1, user2, tokenId);

        vm.prank(user1);
        nft.approve(user2, tokenId);

        assertEq(nft.getApproved(tokenId), user2);
    }

    function test_ApproveNotOwnerReverts() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user2);
        vm.expectRevert();
        nft.approve(user3, tokenId);
    }

    function test_ApprovedCanTransfer() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.approve(user2, tokenId);

        vm.prank(user2);
        nft.transferFrom(user1, user3, tokenId);

        assertEq(nft.ownerOf(tokenId), user3);
    }

    function test_SetApprovalForAll() public {
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(user1, user2, true);

        vm.prank(user1);
        nft.setApprovalForAll(user2, true);

        assertTrue(nft.isApprovedForAll(user1, user2));
    }

    function test_OperatorCanTransferAll() public {
        uint256 tokenId1 = nft.safeMint(user1, TEST_URI_1);
        uint256 tokenId2 = nft.safeMint(user1, TEST_URI_2);

        vm.prank(user1);
        nft.setApprovalForAll(user2, true);

        // user2 可以转移 user1 的所有 NFT
        vm.startPrank(user2);
        nft.transferFrom(user1, user3, tokenId1);
        nft.transferFrom(user1, user3, tokenId2);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId1), user3);
        assertEq(nft.ownerOf(tokenId2), user3);
        assertEq(nft.balanceOf(user3), 2);
    }

    function test_RevokeApprovalForAll() public {
        vm.startPrank(user1);
        nft.setApprovalForAll(user2, true);
        assertTrue(nft.isApprovedForAll(user1, user2));

        nft.setApprovalForAll(user2, false);
        assertFalse(nft.isApprovedForAll(user1, user2));
        vm.stopPrank();
    }

    // ============ 销毁功能测试 ============

    function test_Burn() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, address(0), tokenId);

        vm.prank(user1);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(user1), 0);

        vm.expectRevert();
        nft.ownerOf(tokenId);
    }

    function test_BurnNotOwnerReverts() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user2);
        vm.expectRevert();
        nft.burn(tokenId);
    }

    function test_ApprovedCanBurn() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.approve(user2, tokenId);

        vm.prank(user2);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(user1), 0);
    }

    function test_OperatorCanBurn() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.setApprovalForAll(user2, true);

        vm.prank(user2);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(user1), 0);
    }

    function test_BurnedTokenURIReverts() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.burn(tokenId);

        vm.expectRevert();
        nft.tokenURI(tokenId);
    }

    function test_TokenIdNotReusedAfterBurn() public {
        uint256 tokenId1 = nft.safeMint(user1, TEST_URI_1);
        assertEq(tokenId1, 0);

        vm.prank(user1);
        nft.burn(tokenId1);

        // 销毁后铸造新 NFT，tokenId 应该是 1，不会重用 0
        uint256 tokenId2 = nft.safeMint(user2, TEST_URI_2);
        assertEq(tokenId2, 1);
    }

    // ============ URI 功能测试 ============

    function test_TokenURI() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);
        assertEq(nft.tokenURI(tokenId), TEST_URI_1);
    }

    function test_TokenURINonexistentTokenReverts() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }

    function test_DifferentURIsForDifferentTokens() public {
        uint256 tokenId1 = nft.safeMint(user1, TEST_URI_1);
        uint256 tokenId2 = nft.safeMint(user2, TEST_URI_2);
        uint256 tokenId3 = nft.safeMint(user3, TEST_URI_3);

        assertEq(nft.tokenURI(tokenId1), TEST_URI_1);
        assertEq(nft.tokenURI(tokenId2), TEST_URI_2);
        assertEq(nft.tokenURI(tokenId3), TEST_URI_3);
    }

    function test_URIPersistsAfterTransfer() public {
        uint256 tokenId = nft.safeMint(user1, TEST_URI_1);

        vm.prank(user1);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.tokenURI(tokenId), TEST_URI_1);
    }

    // ============ 余额查询测试 ============

    function test_BalanceOf() public {
        assertEq(nft.balanceOf(user1), 0);

        nft.safeMint(user1, TEST_URI_1);
        assertEq(nft.balanceOf(user1), 1);

        nft.safeMint(user1, TEST_URI_2);
        assertEq(nft.balanceOf(user1), 2);

        nft.safeMint(user2, TEST_URI_3);
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_BalanceOfZeroAddressReverts() public {
        vm.expectRevert();
        nft.balanceOf(address(0));
    }

    // ============ 边界条件测试 ============

    function testFuzz_SafeMint(address to, string memory uri) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0); // 不是合约地址

        uint256 tokenId = nft.safeMint(to, uri);
        assertEq(nft.ownerOf(tokenId), to);
        assertEq(nft.tokenURI(tokenId), uri);
    }

    function testFuzz_Transfer(address from, address to) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(from.code.length == 0 && to.code.length == 0);

        uint256 tokenId = nft.safeMint(from, TEST_URI_1);

        vm.prank(from);
        nft.transferFrom(from, to, tokenId);

        assertEq(nft.ownerOf(tokenId), to);
    }

    function test_MintLargeQuantity() public {
        uint256 quantity = 100;

        for (uint256 i = 0; i < quantity; i++) {
            nft.safeMint(user1, TEST_URI_1);
        }

        assertEq(nft.balanceOf(user1), quantity);
    }

    // ============ 集成测试 ============

    function test_CompleteWorkflow() public {
        // 1. 铸造 NFT
        uint256 tokenId1 = nft.safeMint(user1, TEST_URI_1);
        uint256 tokenId2 = nft.safeMint(user1, TEST_URI_2);

        // 2. 授权
        vm.prank(user1);
        nft.approve(user2, tokenId1);

        // 3. 授权的地址转移 NFT
        vm.prank(user2);
        nft.transferFrom(user1, user2, tokenId1);

        // 4. 设置全局授权
        vm.prank(user1);
        nft.setApprovalForAll(user3, true);

        // 5. 操作员转移 NFT
        vm.prank(user3);
        nft.transferFrom(user1, user3, tokenId2);

        // 6. 销毁 NFT
        vm.prank(user2);
        nft.burn(tokenId1);

        // 验证最终状态
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 0);
        assertEq(nft.balanceOf(user3), 1);
        assertEq(nft.ownerOf(tokenId2), user3);
    }
}

// 辅助合约：可以接收 NFT 的合约
contract NFTReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// 辅助合约：不能接收 NFT 的合约
contract NonNFTReceiver {
    // 没有实现 onERC721Received 函数
}
