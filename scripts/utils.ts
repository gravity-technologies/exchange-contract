// hardhat import should be the first import in the file
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { ethers } from "ethers"

import { Provider as ZkSyncProvider } from "zksync-ethers"

import { hashBytecode } from "zksync-web3/build/src/utils"
import { HardhatRuntimeEnvironment, HttpNetworkConfig, Network, NetworkConfig, NetworksConfig } from "hardhat/types"
import { Address } from "zksync-ethers/build/types"

import type { BigNumberish, BytesLike } from "ethers"
import { REQUIRED_L1_TO_L2_GAS_PER_PUBDATA_LIMIT } from "zksync-web3/build/src/utils"

export const GAS_MULTIPLIER = 1
const CREATE2_PREFIX = ethers.solidityPackedKeccak256(["string"], ["zksyncCreate2"])

// eslint-disable-next-line @typescript-eslint/no-var-requires
export const REQUIRED_L2_GAS_PRICE_PER_PUBDATA =
  require("../lib/era-contracts/SystemConfig.json").REQUIRED_L2_GAS_PRICE_PER_PUBDATA
export const ADDRESS_ONE = "0x0000000000000000000000000000000000000001"
const DEPLOYER_SYSTEM_CONTRACT_ADDRESS = "0x0000000000000000000000000000000000008006"

export function computeL2Create2Address(
  deployerAddress: Address,
  bytecode: BytesLike,
  constructorInput: BytesLike,
  create2Salt: BytesLike
) {
  const senderBytes = ethers.zeroPadValue(deployerAddress, 32)
  const bytecodeHash = hashBytecode(bytecode)
  const constructorInputHash = ethers.keccak256(constructorInput)

  const data = ethers.keccak256(
    ethers.concat([CREATE2_PREFIX, senderBytes, create2Salt, bytecodeHash, constructorInputHash])
  )

  return ethers.dataSlice(data, 12)
}

export function connectContract(hre: HardhatRuntimeEnvironment, target: string | ethers.Addressable, abiJsonPath: string, runner?: ethers.ContractRunner | null | undefined) {
  // Get current working directory
  const pwd = process.cwd()
  const abi = require(pwd + '/' + abiJsonPath).abi
  if (!abi) {
    throw new Error(`Could not load ABI from ${pwd}/${abiJsonPath}`)
  }
  return new ethers.Contract(target, new ethers.Interface(abi), runner)
}

export async function create2DeployFromL1NoFactoryDeps(
  hre: HardhatRuntimeEnvironment,
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  l1SharedBridgeAddress: string,
  wallet: ethers.Wallet,
  bytecode: ethers.BytesLike,
  constructor: ethers.BytesLike,
  create2Salt: ethers.BytesLike,
  l2GasLimit: ethers.BigNumberish,
  gasPrice?: ethers.BigNumberish
) {
  const bridgehub = connectContract(hre, bridgehubAddress, getEraL1Path("IBridgehub", "bridgehub"), wallet)

  const deployerSystemContracts = new ethers.Interface(hre.artifacts.readArtifactSync("lib/era-contracts/l2-contracts/contracts/L2ContractHelper.sol:IContractDeployer").abi)
  const bytecodeHash = hashBytecode(bytecode)
  const calldata = deployerSystemContracts.encodeFunctionData("create2", [create2Salt, bytecodeHash, constructor])
  gasPrice ??= (await wallet.provider!.getFeeData()).gasPrice!

  // pay 5 times the base cost(in L2 base token) to ensure the transaction goes through
  const expectedCost = (
    await bridgehub.l2TransactionBaseCost(chainId, gasPrice, l2GasLimit, REQUIRED_L2_GAS_PRICE_PER_PUBDATA)
  ).mul(5)

  const baseTokenAddress = await bridgehub.baseToken(chainId)
  const baseToken = connectContract(hre, baseTokenAddress, "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", wallet)

  const tx = await baseToken.approve(l1SharedBridgeAddress, expectedCost)
  await tx.wait()

  return await bridgehub.requestL2TransactionDirect({
    chainId,
    l2Contract: DEPLOYER_SYSTEM_CONTRACT_ADDRESS,
    mintValue: expectedCost,
    l2Value: 0,
    l2Calldata: calldata,
    l2GasLimit,
    l2GasPerPubdataByteLimit: REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
    factoryDeps: [],
    refundRecipient: wallet.address,
  })
}

export function createProviders(
  networks: NetworksConfig,
  network: Network
): {
  l1Provider: ethers.Provider
  l2Provider: ZkSyncProvider
} {
  const networkName = network.name

  if (!network.zksync) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'zksync' flag set to 'true'.`
    )
  }

  const networkConfig = network.config

  if (!isHttpNetworkConfig(networkConfig)) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'url' specified.`
    )
  }

  if (networkConfig.ethNetwork === undefined) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'ethNetwork' (layer 1) specified.`
    )
  }

  let l1Provider, l2Provider
  const ethNetwork = networkConfig.ethNetwork

  if (isValidEthNetworkURL(ethNetwork)) {
    l1Provider = new ethers.JsonRpcProvider(ethNetwork)
  } else if (ethNetwork in networks && isHttpNetworkConfig(networks[ethNetwork])) {
    l1Provider = new ethers.JsonRpcProvider((networks[ethNetwork] as HttpNetworkConfig).url)
  } else {
    throw new Error(
      `Failed to resolve ethNetwork.\nNetwork '${networkName}' in 'hardhat.config' needs to have a valid 'ethNetwork' (layer 1) specified.`
    )
  }

  l2Provider = new ZkSyncProvider((network.config as HttpNetworkConfig).url)

  return { l1Provider, l2Provider }
}

export function isHttpNetworkConfig(networkConfig: NetworkConfig): networkConfig is HttpNetworkConfig {
  return "url" in networkConfig
}

export function isValidEthNetworkURL(string: string) {
  try {
    new URL(string)
    return true
  } catch (_) {
    return false
  }
}

export async function getTransparentProxyUpgradeCalldata(hre: HardhatRuntimeEnvironment, target: string) {
  const proxyArtifact = await hre.artifacts.readArtifact("ITransparentUpgradeableProxy")
  const proxyInterface = new ethers.Interface(proxyArtifact.abi)

  return proxyInterface.encodeFunctionData("upgradeTo", [target])
}

export type TxInfo = {
  target: string
  data: BytesLike
  value: BigNumberish
}

export async function getL1ToL2TxInfo(
  hre: HardhatRuntimeEnvironment,
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  to: string,
  l2Calldata: string,
  refundRecipient: string,
  gasPrice: BigInt,
  l2GasLimit: BigInt,
  provider: ethers.Provider
): Promise<TxInfo> {
  const bridgehub = connectContract(hre, bridgehubAddress, getEraL1Path("IBridgehub", "bridgehub"), provider)

  const neededValue = await bridgehub.l2TransactionBaseCost(
    chainId,
    gasPrice,
    l2GasLimit,
    REQUIRED_L1_TO_L2_GAS_PER_PUBDATA_LIMIT
  )

  const l1Calldata = bridgehub.interface.encodeFunctionData("requestL2TransactionDirect", [
    {
      chainId,
      l2Contract: to,
      mintValue: neededValue,
      l2Value: 0,
      l2Calldata,
      l2GasLimit: l2GasLimit,
      l2GasPerPubdataByteLimit: REQUIRED_L1_TO_L2_GAS_PER_PUBDATA_LIMIT,
      factoryDeps: [], // It is assumed that the target has already been deployed
      refundRecipient,
    },
  ])

  return {
    target: await bridgehub.address(),
    data: l1Calldata,
    value: 0,
  }
}

export async function getBaseToken(
  hre: HardhatRuntimeEnvironment,
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  provider: ethers.Provider
) {
  const bridgehub = connectContract(hre, bridgehubAddress, getEraL1Path("IBridgehub", "bridgehub"), provider)
  return await bridgehub.baseToken(chainId)
}

export async function scheduleAndExecuteGovernanceOp(
  hre: HardhatRuntimeEnvironment,
  governance: string,
  l1GovernanceAdmin: ethers.Wallet,
  operation: {
    calls: Array<TxInfo>
    predecessor: string
    salt: string
  }
) {
  const governanceContract = connectContract(hre, governance, getEraL1Path("IGovernance", "governance"), l1GovernanceAdmin)
  const scheduleTx = await governanceContract.scheduleTransparent(operation, 0)
  const scheduleTxReceipt = await scheduleTx.wait()
  const executeTx = await governanceContract.execute(operation)
  const executeTxReceipt = await executeTx.wait()
  return {
    scheduleTxReceipt,
    executeTxReceipt,
  }
}

export async function getGovernanceCalldata(
  hre: HardhatRuntimeEnvironment,
  operation: {
    calls: Array<TxInfo>
    predecessor: string
    salt: string
  },
  provider: ethers.Provider
) {
  const governanceInterface = loadInterface(hre, getEraL1Path("IGovernance", "governance"))
  return {
    scheduleTransparent: governanceInterface.encodeFunctionData("scheduleTransparent", [operation, 0]),
    execute: governanceInterface.encodeFunctionData("execute", [operation]),
  }
}

export function loadInterface(hre: HardhatRuntimeEnvironment, path: string) {
  return new ethers.Interface(hre.artifacts.readArtifactSync(path).abi)
}

export function getEraL1Path(name: string, path?: string) {
  return `lib/era-contracts/l1-contracts/contracts/${path?.concat("/") ?? ""}${name}.sol:${name}`
}

export function getEraL2ABIJsonPath(name: string, path?: string) {
  return `lib/era-contracts/l2-contracts/artifacts-zk/contracts/${path?.concat("/") ?? ""}${name}.sol/${name}.json`
}

export function getExchangeAddress(hre: HardhatRuntimeEnvironment) {
  return (hre.config as any).contractAddresses?.[hre.network.name]?.exchange
}
