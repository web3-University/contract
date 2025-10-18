// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC721
 * @dev ERC721标准接口
 */
interface IERC721 {

    // ==================== 事件 ====================

    /**
     * @dev 当NFT从from转移到to时触发
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev 当NFT的授权地址被设置或更改时触发
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev 当操作员被授权或取消授权时触发
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // ==================== 核心功能 ====================

    /**
     * @dev 返回owner拥有的NFT数量
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @dev 返回tokenId的所有者地址
     */
    function ownerOf(uint256 tokenId) external view returns (address);

    /**
     * @dev 安全转移NFT
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev 安全转移NFT（无数据）
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev 转移NFT
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev 授权地址操作NFT
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev 设置操作员
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev 获取tokenId的授权地址
     */
    function getApproved(uint256 tokenId) external view returns (address);

    /**
     * @dev 检查operator是否是owner的操作员
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

/**
 * @title IERC721Metadata
 * @dev ERC721元数据扩展接口
 */
interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @title IERC721Receiver
 * @dev 接收ERC721的合约必须实现此接口
 */
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
