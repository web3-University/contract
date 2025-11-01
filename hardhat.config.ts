import type { HardhatUserConfig } from 'hardhat/config'

import hardhatVerifyPlugin from '@nomicfoundation/hardhat-verify'
import hardhatKeystorePlugin from '@nomicfoundation/hardhat-keystore'
import hardhatToolboxMochaEthersPlugin from '@nomicfoundation/hardhat-toolbox-mocha-ethers'
import { configVariable } from 'hardhat/config'

const config: HardhatUserConfig = {
  plugins: [hardhatVerifyPlugin, hardhatKeystorePlugin, hardhatToolboxMochaEthersPlugin],
  solidity: {
    profiles: {
      default: {
        version: '0.8.28'
      },
      production: {
        version: '0.8.28',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    }
  },
  networks: {
    hardhatMainnet: {
      type: 'edr-simulated',
      chainType: 'l1'
    },
    hardhatOp: {
      type: 'edr-simulated',
      chainType: 'op'
    },
    localhost: {
      type: 'http',
      chainType: 'l1',
      chainId: 31337,
      url: 'http://127.0.0.1:8545'
    },
    sepolia: {
      type: 'http',
      chainType: 'l1',
      chainId: 11155111,
      url: configVariable('SEPOLIA_RPC_URL'),
      accounts: [configVariable('SEPOLIA_PRIVATE_KEY')]
    }
  },
  verify: {
    etherscan: {
      apiKey: configVariable('ETHERSCAN_API_KEY')
    },
    blockscout: {
      enabled: false
    }
  }
}

export default config
