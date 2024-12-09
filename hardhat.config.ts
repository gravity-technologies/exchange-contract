import fs from "fs"
import path from "path"
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

import "./scripts/deploy-exchange-on-l2-through-l1";
import "./scripts/prove-deployment";
import "./scripts/upgrade-exchange-through-l1-governance";

const config: HardhatUserConfig = {
  defaultNetwork: "inMemoryNode",
  networks: {
    inMemoryNode: {
      url: "http://127.0.0.1:8011",
      ethNetwork: "", // in-memory node doesn't support eth node; removing this line will cause an error
      zksync: true,
      chainId: 260, // found using era_test_node run
    },
    grvtDev: {
      url: "https://zkrpc.zkstg.gravitymarkets.io/",
      ethNetwork: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      zksync: true,
      chainId: 327,
    },
    grvtTestnet: {
      url: "https://rpc.zkdev.gravitymarkets.io",
      ethNetwork: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      zksync: true,
      chainId: 326,
    },
    grvtMainnet: {
      url: "https://zkrpc.mainnet.grvt.io/",
      ethNetwork: `https://eth.drpc.org`,
      zksync: true,
      chainId: 325,
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: "1.5.1",
    settings: {
      isSystem: true,
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
  mocha: {
    timeout: 100000000
  },
}

export default config
