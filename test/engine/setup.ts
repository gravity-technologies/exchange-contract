import { execSync } from "child_process"
import { ethers, formatEther, Wallet } from "ethers"
import path from "path"
import { L2SharedBridgeFactory } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { getDeployerWallet } from "../util"
import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import * as hre from "hardhat"
import { hashBytecode } from "zksync-web3/build/src/utils"
import { Provider, Wallet as ZkWallet } from "zksync-ethers"
import { HttpNetworkConfig } from "hardhat/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { connectContract, getEraL2ABIJsonPath } from "../../scripts/utils"

export async function setupTestEnvironment() {
  const w1 = getDeployerWallet()
  const exchangeContract = await deployContracts()
  const l2SharedBridgeAsL1Bridge = await setupL2SharedBridge(exchangeContract)

  return { exchangeContract, l2SharedBridgeAsL1Bridge, w1 }
}

async function deployContracts() {
  const deployerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
  const deployOptions = { wallet: deployerWallet, silent: true, noVerify: true }

  const exchangeContract = await deployContract("GRVTExchangeTest", [], deployOptions)
  const rtfTestInitializeConfigSigner = "0xA08Ee13480C410De20Ea3d126Ee2a7DaA2a30b7D"

  const l2Deployer = new Deployer(hre, deployerWallet)
  const beaconProxyArtifact = await l2Deployer.loadArtifact("BeaconProxy")

  // just to register the bytecode
  const beacon = await deployContract("UpgradeableBeacon", [exchangeContract.target], deployOptions)
  await deployContract("BeaconProxy", [beacon.target, "0x"], deployOptions)

  await exchangeContract.initialize(
    deployerWallet.address,
    // deployer is also the chain submitter
    deployerWallet.address,
    rtfTestInitializeConfigSigner,
    deployerWallet.address,
    hashBytecode(beaconProxyArtifact.bytecode)
  )

  return exchangeContract
}

async function setupL2SharedBridge(exchangeContract: ethers.Contract) {
  const [deployerWallet, governorWallet, l1BridgeWallet] = LOCAL_RICH_WALLETS.slice(0, 3).map((w) =>
    getWallet(w.privateKey)
  )

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
      ethers.keccak256(ethers.toUtf8Bytes("test")),
    ].join(" "),
    { cwd: path.resolve("lib/era-contracts/l2-contracts"), stdio: "pipe" }
  )

  const l2SharedBridgeAddress = result.toString().trim()
  const l2SharedBridge = getL2SharedBridge(hre, l2SharedBridgeAddress, deployerWallet)

  console.log(`Deployed L2SharedBridge at ${l2SharedBridgeAddress}`)
  for (const token in L2TokenInfo) {
    const tokenAddress = await l2SharedBridge.l2TokenAddress(L2TokenInfo[token].l1Token)
    console.log(`Token ${token} has L2 address ${tokenAddress}`)
  }

  await (await l2SharedBridge.setExchangeAddress(await exchangeContract.target)).wait()

  return getL2SharedBridge(hre, l2SharedBridgeAddress, l1BridgeWallet)
}

function getL2SharedBridge(hre: HardhatRuntimeEnvironment, l2SharedBridgeAddress: string, wallet: ZkWallet) {
  return connectContract(hre, l2SharedBridgeAddress, getEraL2ABIJsonPath("L2SharedBridge", "bridge"), wallet)
}

export const L2TokenInfo: {
  [key: string]: {
    l1Token: string
    erc20Decimals: number
    exchangeDecimals: number
    name: string
  }
} = {
  USDC: {
    l1Token: "0x1111000000000000000000000000000000001110",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "USD Coin",
  },
  USDT: {
    l1Token: "0x1111000000000000000000000000000000001111",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "Tether USD",
  },
  ETH: {
    l1Token: "0x1111000000000000000000000000000000001112",
    erc20Decimals: 18,
    exchangeDecimals: 9,
    name: "Ether",
  },
  BTC: {
    l1Token: "0x1111000000000000000000000000000000001113",
    erc20Decimals: 8,
    exchangeDecimals: 9,
    name: "Wrapped Bitcoin",
  },
}

export const LOCAL_RICH_WALLETS = [
  {
    address: "0x36615Cf349d7F6344891B1e7CA7C72883F5dc049",
    privateKey: "0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110",
  },
  {
    address: "0xa61464658AfeAf65CccaaFD3a512b69A83B77618",
    privateKey: "0xac1e735be8536c6534bb4f17f06f6afc73b2b5ba84ac2cfb12f7461b20c0bbe3",
  },
  {
    address: "0x0D43eB5B8a47bA8900d84AA36656c92024e9772e",
    privateKey: "0xd293c684d884d56f8d6abd64fc76757d3664904e309a0645baf8522ab6366d9e",
  },
  {
    address: "0xA13c10C0D5bd6f79041B9835c63f91de35A15883",
    privateKey: "0x850683b40d4a740aa6e745f889a6fdc8327be76e122f5aba645a5b02d0248db8",
  },
  {
    address: "0x8002cD98Cfb563492A6fB3E7C8243b7B9Ad4cc92",
    privateKey: "0xf12e28c0eb1ef4ff90478f6805b68d63737b7f33abfa091601140805da450d93",
  },
  {
    address: "0x4F9133D1d3F50011A6859807C837bdCB31Aaab13",
    privateKey: "0xe667e57a9b8aaa6709e51ff7d093f1c5b73b63f9987e4ab4aa9a5c699e024ee8",
  },
  {
    address: "0xbd29A1B981925B94eEc5c4F1125AF02a2Ec4d1cA",
    privateKey: "0x28a574ab2de8a00364d5dd4b07c4f2f574ef7fcc2a86a197f65abaec836d1959",
  },
  {
    address: "0xedB6F5B4aab3dD95C7806Af42881FF12BE7e9daa",
    privateKey: "0x74d8b3a188f7260f67698eb44da07397a298df5427df681ef68c45b34b61f998",
  },
  {
    address: "0xe706e60ab5Dc512C36A4646D719b889F398cbBcB",
    privateKey: "0xbe79721778b48bcc679b78edac0ce48306a8578186ffcb9f2ee455ae6efeace1",
  },
  {
    address: "0xE90E12261CCb0F3F7976Ae611A29e84a6A85f424",
    privateKey: "0x3eb15da85647edd9a1159a4a13b9e7c56877c4eb33f614546d4db06a51868b1c",
  },
]

export const verifyEnoughBalance = async (wallet: Wallet, amount: bigint) => {
  // Check if the wallet has enough balance
  const balance = await wallet.provider!.getBalance(wallet.address)
  if (balance < amount)
    throw `⛔️ Wallet balance is too low! Required ${formatEther(amount)} ETH, but current ${wallet.address} balance is ${formatEther(balance)} ETH`
}

/**
 * @param {string} data.contract The contract's path and name. E.g., "contracts/Greeter.sol:Greeter"
 */
export const verifyContract = async (data: {
  address: string
  contract: string
  constructorArguments: string
  bytecode: string
}) => {
  const verificationRequestId: number = await hre.run("verify:verify", {
    ...data,
    noCompile: true,
  })
  return verificationRequestId
}

type DeployContractOptions = {
  /**
   * If true, the deployment process will not print any logs
   */
  silent?: boolean
  /**
   * If true, the contract will not be verified on Block Explorer
   */
  noVerify?: boolean
  /**
   * If specified, the contract will be deployed using this wallet
   */
  wallet?: ZkWallet
}

export const deployContract = async (
  contractArtifactName: string,
  constructorArguments?: any[],
  options?: DeployContractOptions
) => {
  const log = (message: string) => {
    if (!options?.silent) console.log(message)
  }

  log(`\nStarting deployment process of "${contractArtifactName}"...`)

  const wallet = options?.wallet ?? getWallet()
  const deployer = new Deployer(hre, wallet)
  const artifact = await deployer.loadArtifact(contractArtifactName).catch((error) => {
    if (error?.message?.includes(`Artifact for contract "${contractArtifactName}" not found.`)) {
      console.error(error.message)
      throw `⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`
    } else {
      throw error
    }
  })

  // Estimate contract deployment fee
  const deploymentFee = await deployer.estimateDeployFee(artifact, constructorArguments || [])
  log(`Estimated deployment cost: ${formatEther(deploymentFee)} ETH`)

  // Check if the wallet has enough balance
  await verifyEnoughBalance(wallet, deploymentFee)

  // Deploy the contract to zkSync
  const contract = await deployer.deploy(artifact, constructorArguments)

  const constructorArgs = contract.interface.encodeDeploy(constructorArguments)
  const fullContractSource = `${artifact.sourceName}:${artifact.contractName}`

  // Display contract deployment info
  log(`\n"${artifact.contractName}" was successfully deployed:`)
  log(` - Contract address: ${contract.address}`)
  log(` - Contract source: ${fullContractSource}`)
  log(` - Encoded constructor arguments: ${constructorArgs}\n`)

  if (!options?.noVerify && hre.network.config.verifyURL) {
    log(`Requesting contract verification...`)
    await verifyContract({
      address: await contract.address(),
      contract: fullContractSource,
      constructorArguments: constructorArgs,
      bytecode: artifact.bytecode,
    })
  }

  return contract
}

export const getProvider = () => {
  const rpcUrl = (hre.network.config as HttpNetworkConfig).url
  if (!rpcUrl)
    throw `⛔️ RPC URL wasn't found in "${hre.network.name}"! Please add a "url" field to the network config in hardhat.config.ts`

  // Initialize zkSync Provider
  const provider = new Provider(rpcUrl)

  return provider
}

export const getWallet = (privateKey?: string) => {
  if (!privateKey) {
    // Get wallet private key from .env file
    if (!process.env.WALLET_PRIVATE_KEY) throw "⛔️ Wallet private key wasn't found in .env file!"
  }

  const provider = getProvider()

  // Initialize zkSync Wallet
  const wallet = new ZkWallet(privateKey ?? process.env.WALLET_PRIVATE_KEY!, provider)

  return wallet
}