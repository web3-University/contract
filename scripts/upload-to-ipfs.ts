/**
 * 上传NFT元数据到IPFS (使用Pinata)
 *
 * 使用前需要:
 * 1. 在 https://pinata.cloud 注册账号
 * 2. 获取API Key和Secret
 * 3. 在.env文件中设置 PINATA_API_KEY 和 PINATA_API_SECRET
 */

import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const PINATA_JWT = process.env.PINATA_JWT_TOKEN;

/**
 * 上传文件夹到Pinata
 */
async function uploadFolderToPinata(folderPath: string, folderName: string) {
  if (!PINATA_JWT) {
    throw new Error('请在.env文件中设置 PINATA_JWT_TOKEN');
  }

  const url = 'https://api.pinata.cloud/pinning/pinFileToIPFS';
  const formData = new FormData();

  // 读取文件夹中的所有文件
  const files = fs.readdirSync(folderPath);

  for (const file of files) {
    const filePath = path.join(folderPath, file);
    const stat = fs.statSync(filePath);

    if (stat.isFile() && file.endsWith('.json')) {
      const fileStream = fs.createReadStream(filePath);
      formData.append('file', fileStream, {
        filepath: file
      });
    }
  }

  // 设置元数据
  const metadata = JSON.stringify({
    name: folderName,
  });
  formData.append('pinataMetadata', metadata);

  // 设置选项
  const options = JSON.stringify({
    cidVersion: 1,
  });
  formData.append('pinataOptions', options);

  try {
    console.log('正在上传到IPFS...');

    const headers = {
      Authorization: `Bearer ${PINATA_JWT}`
    };

    const response = await axios.post(url, formData, {
      maxBodyLength: Infinity,
      headers: {
        ...headers,
        ...formData.getHeaders(),
      },
    });

    return response.data;
  } catch (error: any) {
    console.error('上传失败:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * 主函数
 */
async function main() {
  const metadataPath = path.join(__dirname, '../metadata');

  console.log('🚀 开始上传NFT元数据到IPFS (Pinata)...\n');

  try {
    const result = await uploadFolderToPinata(metadataPath, 'Yideng-NFT-Metadata');

    console.log('\n✅ 上传成功！');
    console.log('\n📋 IPFS信息:');
    console.log(`CID: ${result.IpfsHash}`);
    console.log(`大小: ${result.PinSize} bytes`);
    console.log(`时间戳: ${result.Timestamp}`);

    console.log('\n🔗 访问链接:');
    console.log(`IPFS网关: https://ipfs.io/ipfs/${result.IpfsHash}/1.json`);
    console.log(`Pinata网关: https://gateway.pinata.cloud/ipfs/${result.IpfsHash}/1.json`);

    console.log('\n📝 下一步:');
    console.log('在部署脚本中更新 baseURI:');
    console.log(`const baseURI = "ipfs://${result.IpfsHash}/";`);

  } catch (error) {
    console.error('\n❌ 上传失败:', error);
    process.exit(1);
  }
}

main().catch(console.error);
