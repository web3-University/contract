/**
 * Chainlink Functions 链下执行脚本示例
 *
 * 此脚本在 Chainlink DON 节点上执行，用于验证学生是否完成课程
 *
 * 参数说明:
 * args[0]: 学生钱包地址 (例如: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
 * args[1]: 课程 ID (例如: "101")
 *
 * 返回值:
 * - 返回 1 表示学生已完成课程
 * - 返回 0 表示学生未完成课程
 * - 抛出错误表示请求失败
 */

// ==================== 方案 1: 调用 REST API ====================

// 从参数中获取学生地址和课程 ID
const studentAddress = args[0];
const courseId = args[1];

// 构建 API URL
const apiUrl = `https://api.web3university.com/courses/${courseId}/students/${studentAddress}/completion`;

// 发起 HTTP 请求
const apiRequest = Functions.makeHttpRequest({
  url: apiUrl,
  method: "GET",
  headers: {
    "Content-Type": "application/json",
    // 如果需要 API Key，可以使用 secrets
    // "Authorization": `Bearer ${secrets.API_KEY}`
  },
  timeout: 9000 // 9秒超时
});

// 等待请求完成
const response = await apiRequest;

// 检查请求是否失败
if (response.error) {
  console.error("API request failed:", response.error);
  throw Error(`API request failed: ${response.message || response.error}`);
}

// 检查 HTTP 状态码
if (response.status !== 200) {
  throw Error(`API returned status ${response.status}`);
}

// 解析响应数据
const data = response.data;

// 验证响应数据格式
if (typeof data.completed !== "boolean") {
  throw Error("Invalid API response format");
}

// 返回结果
if (data.completed === true) {
  // 学生已完成课程
  return Functions.encodeUint256(1);
} else {
  // 学生未完成课程
  return Functions.encodeUint256(0);
}

// ==================== 方案 2: 调用多个 API 进行验证 ====================

/*
// 可以调用多个 API 进行交叉验证
const studentAddress = args[0];
const courseId = args[1];

// API 1: 主数据库
const api1Request = Functions.makeHttpRequest({
  url: `https://api.web3university.com/v1/completion/${studentAddress}/${courseId}`,
  method: "GET"
});

// API 2: 备份数据源
const api2Request = Functions.makeHttpRequest({
  url: `https://backup-api.web3university.com/verify/${studentAddress}/${courseId}`,
  method: "GET"
});

// 并行执行两个请求
const [response1, response2] = await Promise.all([api1Request, api2Request]);

// 验证两个 API 的响应
if (response1.error || response2.error) {
  throw Error("One or more API requests failed");
}

const data1 = response1.data;
const data2 = response2.data;

// 交叉验证: 两个 API 都确认完成才返回成功
if (data1.completed === true && data2.completed === true) {
  return Functions.encodeUint256(1);
} else {
  return Functions.encodeUint256(0);
}
*/

// ==================== 方案 3: 带认证的 API 调用 ====================

/*
// 使用 secrets 存储敏感信息 (如 API Key)
const studentAddress = args[0];
const courseId = args[1];

const response = await Functions.makeHttpRequest({
  url: `https://api.web3university.com/courses/${courseId}/completion`,
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${secrets.API_KEY}`,
    "X-API-Secret": secrets.API_SECRET
  },
  data: {
    studentAddress: studentAddress,
    timestamp: Date.now()
  }
});

if (response.error) {
  throw Error("API request failed");
}

// 验证签名或其他安全措施
const data = response.data;
if (!data.signature || !data.completed) {
  throw Error("Invalid response");
}

return Functions.encodeUint256(data.completed ? 1 : 0);
*/

// ==================== 方案 4: 调用链上合约数据 ====================

/*
// 也可以调用其他链上合约来验证
// 例如，查询学生在另一个合约中的学习进度

const studentAddress = args[0];
const courseId = args[1];

// 调用以太坊 RPC 节点
const rpcRequest = Functions.makeHttpRequest({
  url: `https://mainnet.infura.io/v3/${secrets.INFURA_KEY}`,
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  data: {
    jsonrpc: "2.0",
    method: "eth_call",
    params: [
      {
        to: "0xYourCourseContract",
        data: `0x... encoded function call ...`
      },
      "latest"
    ],
    id: 1
  }
});

const rpcResponse = await rpcRequest;

if (rpcResponse.error) {
  throw Error("RPC request failed");
}

// 解析返回数据
const result = rpcResponse.data.result;
// ... 处理链上数据

return Functions.encodeUint256(1);
*/
