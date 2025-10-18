// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IERC721.sol";

/**
 * @title SimpleYDNFT
 * @dev YD NFT合约（仅管理员可铸造）
 */
contract SimpleYDNFT is IERC721Metadata {

    // ==================== 基础NFT变量 ====================

    string public constant name = "Yideng NFT";
    string public constant symbol = "YDNFT";

    uint256 private _tokenIdCounter;

    address public owner;
    string private _baseTokenURI;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // ==================== 课程证书系统 ====================

    struct Certificate {
        uint256 courseId;           // 课程ID
        string courseName;          // 课程名称
        uint256 completionTime;     // 完成时间
    }

    mapping(uint256 => Certificate) public certificates;

    // ==================== 事件定义 ====================

    event NFTMinted(address indexed to, uint256 indexed tokenId, uint256 courseId, string courseName);
    event BaseURIUpdated(string newBaseURI);

    // ==================== 修饰符 ====================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        _;
    }

    // ==================== 构造函数 ====================

    constructor(string memory baseURI) {
        owner = msg.sender;
        _baseTokenURI = baseURI;
        _tokenIdCounter = 1; // 从1开始，0保留
    }

    // ==================== ERC721标准功能 ====================

    function balanceOf(address ownerAddr) public view override returns (uint256) {
        require(ownerAddr != address(0), "Query for zero address");
        return _balances[ownerAddr];
    }

    function ownerOf(uint256 tokenId) public view override tokenExists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function approve(address to, uint256 tokenId) public override tokenExists(tokenId) {
        address tokenOwner = ownerOf(tokenId);
        require(msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender),
                "Not owner nor approved");
        require(to != tokenOwner, "Approval to current owner");

        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override tokenExists(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != msg.sender, "Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address ownerAddr, address operator) public view override returns (bool) {
        return _operatorApprovals[ownerAddr][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function tokenURI(uint256 tokenId) public view override tokenExists(tokenId) returns (string memory) {
        return string(abi.encodePacked(_baseTokenURI, _toString(tokenId), ".json"));
    }

    // ==================== NFT铸造功能 ====================

    /**
     * @dev 铸造课程证书NFT
     * @param to 接收地址（学生地址）
     * @param courseId 课程ID
     * @param courseName 课程名称
     * @param completionTime 完成时间（时间戳）
     */
    function mintCertificate(
        address to,
        uint256 courseId,
        string memory courseName,
        uint256 completionTime
    ) external onlyOwner returns (uint256) {
        require(to != address(0), "Mint to zero address");
        require(bytes(courseName).length > 0, "Course name cannot be empty");
        require(completionTime > 0, "Invalid completion time");

        uint256 tokenId = _tokenIdCounter;
        _mint(to, tokenId);

        // 保存证书信息
        certificates[tokenId] = Certificate({
            courseId: courseId,
            courseName: courseName,
            completionTime: completionTime
        });

        _tokenIdCounter++;

        emit NFTMinted(to, tokenId, courseId, courseName);

        return tokenId;
    }

    // ==================== 查询功能 ====================

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter - 1;
    }

    /**
     * @dev 获取某个地址拥有的所有NFT
     */
    function getTokensByOwner(address ownerAddr) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(ownerAddr);
        uint256[] memory tokens = new uint256[](balance);
        uint256 index = 0;

        for (uint256 i = 1; i < _tokenIdCounter && index < balance; i++) {
            if (_owners[i] == ownerAddr) {
                tokens[index] = i;
                index++;
            }
        }

        return tokens;
    }

    /**
     * @dev 获取证书信息
     */
    function getCertificate(uint256 tokenId) external view tokenExists(tokenId) returns (Certificate memory) {
        return certificates[tokenId];
    }

    /**
     * @dev 检查用户是否拥有某课程的证书
     */
    function hasCertificate(address student, uint256 courseId) external view returns (bool) {
        uint256 balance = balanceOf(student);
        if (balance == 0) return false;

        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (_owners[i] == student && certificates[i].courseId == courseId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev 获取用户某课程的所有证书Token IDs
     */
    function getCertificatesByCourse(address student, uint256 courseId)
        external view returns (uint256[] memory) {

        // 先计算数量
        uint256 count = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (_owners[i] == student && certificates[i].courseId == courseId) {
                count++;
            }
        }

        // 创建结果数组
        uint256[] memory tokenIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (_owners[i] == student && certificates[i].courseId == courseId) {
                tokenIds[index] = i;
                index++;
            }
        }

        return tokenIds;
    }

    // ==================== 内部函数 ====================

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "Mint to zero address");
        require(_owners[tokenId] == address(0), "Token already minted");

        _balances[to]++;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "Transfer from incorrect owner");
        require(to != address(0), "Transfer to zero address");

        delete _tokenApprovals[tokenId];

        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "Transfer to non-receiver");
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner ||
                getApproved(tokenId) == spender ||
                isApprovedForAll(tokenOwner, spender));
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data)
            private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
                    returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        }
        return true;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

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

    // ==================== 管理员功能 ====================

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
