本地部署步骤：
1.执行npx hardhat node
2.在另一个终端执行npx hardhat ignition deploy --network localhost ignition/modules/SimpleYDToken.ts 
3.然后再执行npx hardhat ignition deploy --network localhost ignition/modules/CourseContract.ts
4.想部署到sepolia上的，需要去/ignition/modules/CourseContract.ts中修改chainId和讲师的地址