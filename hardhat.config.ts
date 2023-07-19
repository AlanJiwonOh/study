import { HardhatUserConfig } from "hardhat/types";

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import 'hardhat-typechain'
import 'hardhat-watcher'
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import 'solidity-coverage'

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.8.18',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const config: HardhatUserConfig = {
  networks: {
      hardhat: {
          mining: {
              auto: true,
              interval: 2000,
          },
          forking: {
              url: "https://polygon-rpc.com"
          }
      },
      polygon: {
          url: "https://polygon-rpc.com"
      },
  },
  solidity: {
    compilers: [DEFAULT_COMPILER_SETTINGS]
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
}

export default config;