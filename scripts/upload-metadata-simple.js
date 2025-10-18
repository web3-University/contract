/**
 * 简单的上传NFT元数据到IPFS脚本 (使用Pinata)
 * 不需要额外安装依赖包
 */

import fs from 'fs';
import path from 'path';

const PINATA_JWT = process.env.PINATA_JWT_TOKEN || '';

if (!PINATA_JWT) {
  console.error('❌ 错误: 请在.env文件中设置 PINATA_JWT_TOKEN');
  process.exit(1);
}

/**
 * 上传单个JSON文件到Pinata
 */
async function uploadJsonToPinata(filePath: string, fileName: string) {
  const fileContent = fs.readFileSync(filePath, 'utf-8');

  const data = JSON.stringify({
    pinataContent: JSON.parse(fileContent),
    pinataMetadata: {
      name: fileName
    }
  });

  const response = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${PINATA_JWT}`
    },
    body: data
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`上传失败: ${error}`);
  }

  return await response.json();
}

/**
 * 主函数
 */
async function main() {
  const metadataPath = path.join(__dirname, '../metadata');
  const files = fs.readdirSync(metadataPath).filter(f => f.endsWith('.json'));

  console.log('🚀 开始上传NFT元数据到IPFS...\n');

  const uploadedFiles: any[] = [];

  for (const file of files) {
    try {
      const filePath = path.join(metadataPath, file);
      console.log(`📤 上传 ${file}...`);

      const result = await uploadJsonToPinata(filePath, file);
      uploadedFiles.push({ file, cid: result.IpfsHash });

      console.log(`✅ ${file} -> ipfs://${result.IpfsHash}`);
    } catch (error: any) {
      console.error(`❌ ${file} 上传失败:`, error.message);
    }
  }

  console.log('\n📋 上传完成！');
  console.log('\n已上传的文件:');
  uploadedFiles.forEach(({ file, cid }) => {
    console.log(`  ${file}: https://gateway.pinata.cloud/ipfs/${cid}`);
  });

  if (uploadedFiles.length > 0) {
    console.log('\n💡 提示: 这些是单个JSON文件的CID');
    console.log('建议将所有JSON文件放在一个文件夹中上传，这样可以得到统一的baseURI');
    console.log('访问 https://app.pinata.cloud 手动上传metadata文件夹以获得文件夹CID');
  }
}

main().catch(console.error);
