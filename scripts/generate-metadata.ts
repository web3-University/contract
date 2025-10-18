/**
 * NFT元数据生成脚本
 * 用于批量生成课程证书的元数据JSON文件
 */

import fs from 'fs';
import path from 'path';

interface CourseMetadata {
  courseId: number;
  courseName: string;
  description: string;
  difficulty: string;
  imageFileName?: string;
}

// 课程列表
const courses: CourseMetadata[] = [
  {
    courseId: 1,
    courseName: "区块链开发入门",
    description: "恭喜完成区块链开发入门课程！这是您获得的课程完成证书NFT，证明您已经掌握了区块链开发的基础知识。",
    difficulty: "入门",
    imageFileName: "certificate-1.png"
  },
  {
    courseId: 2,
    courseName: "Solidity智能合约进阶",
    description: "恭喜完成Solidity智能合约进阶课程！您已经掌握了智能合约开发的高级技巧。",
    difficulty: "进阶",
    imageFileName: "certificate-2.png"
  },
  {
    courseId: 3,
    courseName: "DeFi协议开发实战",
    description: "恭喜完成DeFi协议开发实战课程！您已经具备开发去中心化金融应用的能力。",
    difficulty: "高级",
    imageFileName: "certificate-3.png"
  },
  // 可以继续添加更多课程...
];

/**
 * 生成单个课程的元数据
 */
function generateMetadata(course: CourseMetadata, imageCID: string = "bafybeiaccount"): object {
  return {
    name: `Yideng NFT #${course.courseId} - ${course.courseName}`,
    description: course.description,
    image: `ipfs://${imageCID}/${course.imageFileName || `certificate-${course.courseId}.png`}`,
    external_url: `https://yideng.com/courses/${course.courseId}`,
    attributes: [
      {
        trait_type: "课程ID",
        value: course.courseId
      },
      {
        trait_type: "课程名称",
        value: course.courseName
      },
      {
        trait_type: "证书类型",
        value: "课程完成证书"
      },
      {
        trait_type: "难度级别",
        value: course.difficulty
      },
      {
        trait_type: "发行机构",
        value: "壹灯大学"
      }
    ]
  };
}

/**
 * 批量生成所有元数据文件
 */
async function generateAllMetadata() {
  const metadataDir = path.join(__dirname, '../metadata');

  // 确保metadata目录存在
  if (!fs.existsSync(metadataDir)) {
    fs.mkdirSync(metadataDir, { recursive: true });
  }

  console.log('开始生成NFT元数据文件...\n');

  // 生成每个课程的元数据
  for (const course of courses) {
    const metadata = generateMetadata(course);
    const filePath = path.join(metadataDir, `${course.courseId}.json`);

    fs.writeFileSync(filePath, JSON.stringify(metadata, null, 2));
    console.log(`✅ 已生成: ${course.courseId}.json - ${course.courseName}`);
  }

  console.log(`\n✨ 成功生成 ${courses.length} 个元数据文件！`);
  console.log(`📁 文件位置: ${metadataDir}`);
  console.log('\n下一步:');
  console.log('1. 准备对应的证书图片');
  console.log('2. 上传图片到IPFS，获得CID');
  console.log('3. 更新脚本中的imageCID');
  console.log('4. 重新生成元数据');
  console.log('5. 上传metadata文件夹到IPFS');
  console.log('6. 更新部署脚本中的baseURI');
}

// 执行生成
generateAllMetadata().catch(console.error);
