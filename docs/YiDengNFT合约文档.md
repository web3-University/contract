# YiDengNFT 合约文档

## 合约概述

YiDengNFT (YDNFT) 是一个基于 ERC721 标准的 NFT 合约，支持铸造、销毁和 URI 存储功能。合约继承了 OpenZeppelin 的 ERC721、ERC721URIStorage、ERC721Burnable 和 Ownable 模块，提供了 NFT 的完整功能实现。

---

## NFT 信息

- **NFT 名称**: YiDengNFT
- **NFT 符号**: YDNFT
- **标准**: ERC721
- **Solidity 版本**: ^0.8.28
- **许可证**: MIT

---

## 核心功能

### 1. 安全铸造 NFT

```solidity
function safeMint(address to, string memory uri) public onlyOwner returns (uint256)
```

- **功能**: 向指定地址铸造新的 NFT 并设置元数据 URI
- **权限**: 仅合约所有者
- **参数**:
  - `to`: 接收 NFT 的地址
  - `uri`: NFT 的元数据 URI（通常指向 JSON 文件）
- **返回值**: 新铸造的 NFT 的 tokenId
- **特性**: 
  - 自动递增 tokenId
  - 使用 `_safeMint` 确保接收方可以安全接收 NFT
  - 自动设置 token URI

### 2. NFT 销毁

继承自 `ERC721Burnable`，提供以下功能：
- NFT 持有者可以销毁自己的 NFT
- 授权地址可以销毁被授权的 NFT
- 销毁后 NFT 永久失效，tokenId 不可重用

### 3. URI 存储与查询

```solidity
function tokenURI(uint256 tokenId) public view returns (string memory)
```

- **功能**: 查询指定 NFT 的元数据 URI
- **参数**: `tokenId` - NFT 的唯一标识符
- **返回值**: 该 NFT 的元数据 URI 字符串
- **前置条件**: tokenId 必须存在（未被销毁）

### 4. NFT 转账

继承自 `ERC721`，支持标准的 NFT 转账功能：
- `transferFrom(address from, address to, uint256 tokenId)`: 普通转账
- `safeTransferFrom(address from, address to, uint256 tokenId)`: 安全转账
- `safeTransferFrom(address from, address to, uint256 tokenId, bytes data)`: 带数据的安全转账

### 5. 授权管理

继承自 `ERC721`，支持标准的授权功能：
- `approve(address to, uint256 tokenId)`: 授权单个 NFT
- `setApprovalForAll(address operator, bool approved)`: 授权所有 NFT
- `getApproved(uint256 tokenId)`: 查询单个 NFT 的授权地址
- `isApprovedForAll(address owner, address operator)`: 查询全局授权状态

---

## 状态变量

| 变量名 | 类型 | 可见性 | 说明 |
|--------|------|--------|------|
| `_nextTokenId` | uint256 | private | 下一个将要铸造的 tokenId，从 0 开始自动递增 |

---

## 事件

### Transfer（继承自 ERC721）

```solidity
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
```

- **触发时机**: NFT 转移、铸造或销毁时
- **参数**:
  - `from`: 发送方地址（铸造时为 0x0）
  - `to`: 接收方地址（销毁时为 0x0）
  - `tokenId`: NFT 的 tokenId

### Approval（继承自 ERC721）

```solidity
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)
```

- **触发时机**: NFT 授权状态改变时
- **参数**:
  - `owner`: NFT 所有者地址
  - `approved`: 被授权地址
  - `tokenId`: 被授权的 tokenId

### ApprovalForAll（继承自 ERC721）

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
```

- **触发时机**: 全局授权状态改变时
- **参数**:
  - `owner`: NFT 所有者地址
  - `operator`: 操作员地址
  - `approved`: 授权状态

---

## 权限控制

合约使用 OpenZeppelin 的 `Ownable` 模式进行权限管理：

| 功能 | 权限要求 |
|------|----------|
| 铸造 NFT (`safeMint`) | 仅所有者 |
| 转移 NFT | NFT 所有者或授权地址 |
| 销毁 NFT | NFT 所有者或授权地址 |
| 授权 NFT | NFT 所有者 |
| 转移合约所有权 | 当前所有者 |

---

## 使用流程

### 初始化流程

1. 部署合约，指定初始所有者地址
2. 合约即可开始使用，无需额外配置

### 铸造 NFT 流程

```solidity
// 所有者铸造 NFT
string memory metadataURI = "ipfs://QmXxx...";
uint256 tokenId = nft.safeMint(userAddress, metadataURI);
```

### 转移 NFT 流程

```solidity
// 方式一：普通转账
nft.transferFrom(fromAddress, toAddress, tokenId);

// 方式二：安全转账（推荐）
nft.safeTransferFrom(fromAddress, toAddress, tokenId);
```

### 授权流程

```solidity
// 授权单个 NFT
nft.approve(operatorAddress, tokenId);

// 授权所有 NFT
nft.setApprovalForAll(operatorAddress, true);
```

### 销毁 NFT 流程

```solidity
// 持有者或授权地址销毁 NFT
nft.burn(tokenId);
```

---

## 接口实现

### ERC721 标准接口

- ✅ `balanceOf(address owner)`: 查询地址持有的 NFT 数量
- ✅ `ownerOf(uint256 tokenId)`: 查询 NFT 的所有者
- ✅ `transferFrom(address from, address to, uint256 tokenId)`: 转移 NFT
- ✅ `safeTransferFrom(address from, address to, uint256 tokenId)`: 安全转移 NFT
- ✅ `approve(address to, uint256 tokenId)`: 授权 NFT
- ✅ `setApprovalForAll(address operator, bool approved)`: 全局授权
- ✅ `getApproved(uint256 tokenId)`: 查询授权地址
- ✅ `isApprovedForAll(address owner, address operator)`: 查询全局授权状态

### ERC721Metadata 接口

- ✅ `name()`: 返回 "YiDengNFT"
- ✅ `symbol()`: 返回 "YDNFT"
- ✅ `tokenURI(uint256 tokenId)`: 返回 NFT 元数据 URI

### ERC165 接口

- ✅ `supportsInterface(bytes4 interfaceId)`: 接口检测

---

## 元数据标准

### URI 格式

推荐使用以下 URI 格式：
- **IPFS**: `ipfs://QmXxx...`
- **HTTP/HTTPS**: `https://example.com/metadata/1.json`
- **Data URI**: `data:application/json;base64,...`

### 元数据 JSON 格式

```json
{
  "name": "YiDeng NFT #1",
  "description": "This is a YiDeng NFT",
  "image": "ipfs://QmYxx...",
  "attributes": [
    {
      "trait_type": "Background",
      "value": "Blue"
    },
    {
      "trait_type": "Rarity",
      "value": "Legendary"
    }
  ]
}
```

---

## 安全特性

1. **权限隔离**: 铸造功能仅限所有者操作
2. **安全铸造**: 使用 `_safeMint` 确保接收方可以安全接收 NFT
3. **标准兼容**: 完全兼容 ERC721 标准，支持主流 NFT 市场
4. **URI 存储**: 支持链上存储元数据 URI
5. **事件记录**: 所有关键操作都会触发标准事件
6. **接口检测**: 支持 ERC165 接口检测

---

## 注意事项

⚠️ **重要提示**:

1. **TokenId 连续性**: TokenId 从 0 开始连续递增，即使销毁 NFT 也不会重用 tokenId
2. **URI 不可变**: 一旦设置 URI，无法修改（除非扩展合约添加更新功能）
3. **所有者权限**: 只有所有者可以铸造 NFT，需妥善保管私钥
4. **元数据存储**: URI 只存储链接，实际元数据需要存储在 IPFS 或其他服务器上
5. **Gas 费用**: 铸造 NFT 需要消耗 gas 费用，包含 URI 存储成本
6. **安全审计**: 建议在主网部署前进行完整的安全审计

---

## 合约地址

- **网络**: [待部署]
- **合约地址**: [待部署]
- **所有者地址**: [待部署]

---

## 版本历史

- **v1.0**: 初始版本，支持 NFT 铸造、转移、销毁和 URI 存储功能

---

## 相关链接

- **OpenZeppelin 文档**: https://docs.openzeppelin.com/contracts/
- **ERC721 标准**: https://eips.ethereum.org/EIPS/eip-721
- **IPFS**: https://ipfs.io/
- **NFT 元数据标准**: https://docs.opensea.io/docs/metadata-standards