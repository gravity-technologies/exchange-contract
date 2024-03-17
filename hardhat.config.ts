// import "@nomicfoundation/hardhat-foundry"
import "@matterlabs/hardhat-zksync-node"
// https://github.com/matter-labs/hardhat-zksync/issues/711
// duplication occurs within matter labs monorepo setup so we need to import from the dist folder
import "@matterlabs/hardhat-zksync-deploy/dist/deployer"
import "@matterlabs/hardhat-zksync-solc"
import "@matterlabs/hardhat-zksync-verify"
import "@matterlabs/hardhat-zksync-chai-matchers"
import "@typechain/hardhat"
// upgradable plugin
import "@matterlabs/hardhat-zksync-upgradable"

import { HardhatUserConfig } from "hardhat/config"
const config: HardhatUserConfig = {
  defaultNetwork: "grvtDev",
  networks: {
    zkSyncSepoliaTestnet: {
      url: "https://sepolia.era.zksync.dev",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: "https://explorer.sepolia.era.zksync.dev/contract_verification",
    },
    zkSyncMainnet: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "mainnet",
      zksync: true,
      verifyURL: "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
    },
    zkSyncGoerliTestnet: {
      // deprecated network
      url: "https://testnet.era.zksync.dev",
      ethNetwork: "goerli",
      zksync: true,
      verifyURL: "https://zksync2-testnet-explorer.zksync.dev/contract_verification",
    },
    dockerizedNode: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    inMemoryNode: {
      url: "http://127.0.0.1:8011",
      ethNetwork: "", // in-memory node doesn't support eth node; removing this line will cause an error
      zksync: true,
      chainId: 260, // found using era_test_node run
    },
    grvtTestnet: {
      url: "https://zkstack.testnet.grvt.internal",
      ethNetwork: "http://zkstack.testnet.internal:8545",
      zksync: true,
      chainId: 270,
    },
    grvtDev: {
      url: "http://zkstack.dev.grvt.internal",
      ethNetwork: "http://zkstack.dev.grvt.internal:8545",
      zksync: true,
      chainId: 270,
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: "latest",
    settings: {
      // find all available options in the official documentation
      // https://era.zksync.io/docs/tools/hardhat/hardhat-zksync-solc.html#configuration
    },
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 5,
      },
    },
  },
}

export default config
