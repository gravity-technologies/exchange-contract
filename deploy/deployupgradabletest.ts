import { execSync } from "child_process"
import { ethers } from "ethers"
import path from "path"
import { L2SharedBridge } from "../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { L2SharedBridgeFactory } from "../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { L2TokenInfo } from "./testutil"
import { LOCAL_RICH_WALLETS, deployContractUpgradable, getWallet } from "./utils"

let l2SharedBridgeAsL1Bridge: L2SharedBridge

// Deploy Upgradable Script
export default async function () {
  const contractArtifactName = "GRVTExchangeTest"
  const exchangeContract = await deployContractUpgradable(contractArtifactName)
  const [deployerWallet, governorWallet, l1BridgeWallet] = LOCAL_RICH_WALLETS.slice(0, 3).map((w) =>
    getWallet(w.privateKey)
  )

  // setup L2SharedBridge and BeaconProxy for L2StandardERC20 for deposit and withdrawal
  // DO NOT update the salt as it would change the deployed contract address, which is fixed across runs and
  // hardcoded in risk RTF tests
  const result = execSync(
    [
      "npx",
      "hardhat",
      "deploy-erc20-test-setup",
      "--deployer-private-key",
      deployerWallet.privateKey,
      "--governor-private-key",
      governorWallet.privateKey,
      "--l1-bridge-private-key",
      l1BridgeWallet.privateKey,
      "--salt",
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test")),
    ].join(" "),
    { cwd: path.resolve("lib/era-contracts/l2-contracts"), stdio: "pipe" }
  )

  const l2SharedBridgeAddress = result.toString().trim()
  const l2SharedBridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, deployerWallet)

  console.log(`Deployed L2SharedBridge at ${l2SharedBridgeAddress}`)
  for (const token in L2TokenInfo) {
    const tokenAddress = await l2SharedBridge.l2TokenAddress(L2TokenInfo[token].l1Token)
    console.log(`Token ${token} has L2 address ${tokenAddress}`)
  }

  // exchange address is required before ERC20 can be deployed
  await (await l2SharedBridge.setExchangeAddress(exchangeContract.address)).wait()

  l2SharedBridgeAsL1Bridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, l1BridgeWallet)
}
