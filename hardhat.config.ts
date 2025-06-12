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

// Add this before the config
declare module "hardhat/types/config" {
  interface HardhatUserConfig {
    contractAddresses?: {
      [network: string]: {
        exchange: string;
        multicall3: string;
      };
    };
  }
}

import "./scripts/deploy-exchange-on-l2-through-l1";
import "./scripts/set-exchange-address";
import "./scripts/upgrade-exchange-through-l1-governance";
import "./scripts/replay-tx";
import "./scripts/parse-tx";
import "./scripts/fork";
import "./scripts/migrate-diamond-through-l1-governance";
import "./scripts/check-diamond-facets";

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
      ethNetwork: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
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
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  mocha: {
    timeout: 100000000
  },
  contractAddresses: {
    grvtMainnet: {
      exchange: "0x85dee82d32d78eaa59588b6574df420ef2a74098",
      multicall3: "0xB787151147A17A7d91Ffab30A11B80B4868901d3"
    },
    grvtTestnet: {
      exchange: "0x9faca433bc7723e056f7e88bbb464c7b0d894e93",
      multicall3: "0x3a435A467f19c24f3f867F6C40a7ea628C410998"
    },
    grvtDev: {
      exchange: "0x45ce10dd2014ad01027b745bf34eb12840bda881",
      multicall3: "0xD53767fC3b7Cc71d22BDeCf6C9C8C6207CfF11C9"
    }
  }
}

export default config
