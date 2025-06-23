// hardhat import should be the first import in the file
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { Contract, ethers } from "ethers"

import { Interface } from "ethers/lib/utils"

import { Provider as ZkSyncProvider } from "zksync-ethers"
import { IBridgehubFactory } from "../lib/era-contracts/l1-contracts/typechain/IBridgehubFactory"
import { IGovernanceFactory } from "../lib/era-contracts/l1-contracts/typechain/IGovernanceFactory"

import { IERC20Factory } from "zksync-web3/build/typechain"

import { hashBytecode } from "zksync-web3/build/src/utils"
import { HardhatRuntimeEnvironment, HttpNetworkConfig, Network, NetworkConfig, NetworksConfig } from "hardhat/types"
import { Address } from "zksync-ethers/build/src/types"

import { Deployer } from "@matterlabs/hardhat-zksync-deploy/dist/deployer"

import { BigNumber, BigNumberish, BytesLike } from "ethers"
import { REQUIRED_L1_TO_L2_GAS_PER_PUBDATA_LIMIT } from "zksync-web3/build/src/utils"
import { ExchangeFacetInfos } from "./diamond-info"

export const GAS_MULTIPLIER = 1
const CREATE2_PREFIX = ethers.utils.solidityKeccak256(["string"], ["zksyncCreate2"])

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
  const senderBytes = ethers.utils.hexZeroPad(deployerAddress, 32)
  const bytecodeHash = hashBytecode(bytecode)
  const constructorInputHash = ethers.utils.keccak256(constructorInput)

  const data = ethers.utils.keccak256(
    ethers.utils.concat([CREATE2_PREFIX, senderBytes, create2Salt, bytecodeHash, constructorInputHash])
  )

  return ethers.utils.hexDataSlice(data, 12)
}

export async function deployFromL1NoFactoryDepsNoConstructor(
  hre: HardhatRuntimeEnvironment,
  chainId: ethers.BigNumberish,
  bridgeHub: string,
  l1SharedBridge: string,
  l1Deployer: ethers.Wallet,
  l2Deployer: Deployer,
  artifactName: string,
  salt: string
) {
  const artifact = await l2Deployer.loadArtifact(artifactName)
  const codehash = hashBytecode(artifact.bytecode)
  await l2Deployer.deploy(artifact, [])

  console.log(`${artifactName} L2 codehash registered: ${ethers.utils.hexlify(codehash)}`)

  const emptyConstructorData = ethers.utils.arrayify("0x")
  const expectedNewImplAddress = computeL2Create2Address(
    l2Deployer.zkWallet.address,
    artifact.bytecode,
    emptyConstructorData,
    salt
  )

  // deploy an instance of the impl with CREATE2
  const newImplDepTx = await create2DeployFromL1NoFactoryDeps(
    hre,
    chainId,
    bridgeHub,
    l1SharedBridge,
    l1Deployer,
    artifact.bytecode,
    emptyConstructorData,
    salt,
    1000000
  )
  const newImplDepTxReceipt = await newImplDepTx.wait()

  console.log(`Expected ${artifactName} impl address: ${expectedNewImplAddress}`)
  console.log(`${artifactName} impl deployment tx hash: ${newImplDepTx.hash}`)
  console.log(`${artifactName} impl deployment stauts: ${newImplDepTxReceipt.status}`)

  return {
    artifactName,
    address: expectedNewImplAddress,
  }
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
  const bridgehub = IBridgehubFactory.connect(bridgehubAddress, wallet)

  const deployerSystemContracts = new Interface(hre.artifacts.readArtifactSync("lib/era-contracts/l2-contracts/contracts/L2ContractHelper.sol:IContractDeployer").abi)
  const bytecodeHash = hashBytecode(bytecode)
  const calldata = deployerSystemContracts.encodeFunctionData("create2", [create2Salt, bytecodeHash, constructor])
  gasPrice ??= await bridgehub.provider.getGasPrice()

  // pay 5 times the base cost(in L2 base token) to ensure the transaction goes through
  const expectedCost = (
    await bridgehub.l2TransactionBaseCost(chainId, gasPrice, l2GasLimit, REQUIRED_L2_GAS_PRICE_PER_PUBDATA)
  ).mul(5)

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

const BASE_TOKEN_ALLOWANCE = BigNumber.from("100000000000000000000")

export async function approveL1SharedBridgeIfNeeded(
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  l1SharedBridgeAddress: string,
  wallet: ethers.Wallet,
) {
  const bridgehub = IBridgehubFactory.connect(bridgehubAddress, wallet)
  const baseTokenAddress = await bridgehub.baseToken(chainId)
  const baseToken = IERC20Factory.connect(baseTokenAddress, wallet)
  const allowance = await baseToken.allowance(wallet.address, l1SharedBridgeAddress)
  if (allowance.lt(BASE_TOKEN_ALLOWANCE.div(2))) {
    const tx = await baseToken.approve(l1SharedBridgeAddress, BASE_TOKEN_ALLOWANCE)
    await tx.wait()
  }
}

export function createProviders(
  networks: NetworksConfig,
  network: Network
): {
  l1Provider: ethers.providers.BaseProvider
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
    l1Provider = new ethers.providers.JsonRpcProvider(ethNetwork)
  } else if (ethNetwork in networks && isHttpNetworkConfig(networks[ethNetwork])) {
    l1Provider = new ethers.providers.JsonRpcProvider((networks[ethNetwork] as HttpNetworkConfig).url)
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

export async function encodeTransparentProxyUpgradeTo(hre: HardhatRuntimeEnvironment, target: string) {
  const proxyArtifact = await hre.artifacts.readArtifact("ITransparentUpgradeableProxy")
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi)

  return proxyInterface.encodeFunctionData("upgradeTo", [target])
}

export async function encodeTransparentProxyUpgradeToAndCall(hre: HardhatRuntimeEnvironment, target: string, calldata: string) {
  const proxyArtifact = await hre.artifacts.readArtifact("ITransparentUpgradeableProxy")
  const proxyInterface = new ethers.utils.Interface(proxyArtifact.abi)

  return proxyInterface.encodeFunctionData("upgradeToAndCall", [target, calldata])
}

export type TxInfo = {
  target: string
  data: BytesLike
  value: BigNumberish
}

export async function getL1ToL2TxInfo(
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  to: string,
  l2Calldata: string,
  refundRecipient: string,
  gasPrice: BigNumber,
  l2GasLimit: BigNumber,
  provider: ethers.providers.BaseProvider
): Promise<TxInfo> {
  const bridgehub = IBridgehubFactory.connect(bridgehubAddress, provider)

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
    target: bridgehub.address,
    data: l1Calldata,
    value: 0,
  }
}

export async function getBaseToken(
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  provider: ethers.providers.BaseProvider
) {
  const bridgehub = IBridgehubFactory.connect(bridgehubAddress, provider)
  return await bridgehub.baseToken(chainId)
}

export async function scheduleAndExecuteGovernanceOp(
  governance: string,
  l1GovernanceAdmin: ethers.Wallet,
  operation: {
    calls: Array<TxInfo>
    predecessor: string
    salt: string
  }
) {
  const governanceContract = IGovernanceFactory.connect(governance, l1GovernanceAdmin)
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
  operation: {
    calls: Array<TxInfo>
    predecessor: string
    salt: string
  },
  provider: ethers.providers.BaseProvider
) {
  const governanceContract = IGovernanceFactory.connect(ethers.Wallet.createRandom().address, provider)
  return {
    scheduleTransparent: governanceContract.interface.encodeFunctionData("scheduleTransparent", [operation, 0]),
    execute: governanceContract.interface.encodeFunctionData("execute", [operation]),
  }
}

export enum FacetCutAction {
  Add = 0,
  Replace = 1,
  Remove = 2
}

/**
 * Generate diamond cut data for new facet methods
 * @param facetInfos Array of facet contract instances
 * @returns Diamond cut data for facet methods
 */
export async function generateDiamondCutDataForNewFacets(facetInfos: Array<{ address: string, abi: any[] }>) {
  // Create diamond cut data array
  const diamondCut = [];

  for (const { address, abi } of facetInfos) {
    // Create interface from ABI
    const facetInterface = new ethers.utils.Interface(abi);

    // Get all function selectors from the facet
    const selectors = [];
    for (const fn of Object.keys(facetInterface.functions)) {
      selectors.push(facetInterface.getSighash(fn));
    }

    diamondCut.push({
      facetAddress: address,
      action: FacetCutAction.Add,
      functionSelectors: selectors
    });
  }

  return diamondCut;
}

export async function validateHybridProxy(hre: HardhatRuntimeEnvironment, facets: {
  facet: string,
  selectors: string[],
}[]) {
  const mainContract = await hre.artifacts.readArtifact("GRVTExchange")
  const mainAbiInterface = new ethers.utils.Interface(mainContract.abi);
  const mainAbiSelectors = Object.keys(mainAbiInterface.functions).map(fn => mainAbiInterface.getSighash(fn));

  // Check for duplicate selectors in the diamond cut data
  const allSelectors = [];
  const selectorMap = new Map();

  for (let i = 0; i < facets.length; i++) {
    const facet = facets[i];
    const facetSelectors = facet.selectors;

    for (let j = 0; j < facetSelectors.length; j++) {
      const selector = facetSelectors[j];

      if (selectorMap.has(selector)) {
        console.error(`DUPLICATE SELECTOR: ${selector} found in both:`);
        console.error(`1. ${selectorMap.get(selector)}`);
        console.error(`2. ${facet.facet}`);
        return false;
      }

      selectorMap.set(selector, facet.facet);
      allSelectors.push(selector);
    }
  }

  // Check if any selector in the ABI is also in the diamond cut data
  for (let i = 0; i < mainAbiSelectors.length; i++) {
    const abiSelector = mainAbiSelectors[i];

    if (allSelectors.includes(abiSelector)) {
      console.error(`CONFLICT: Selector ${abiSelector} from the ABI is also in the diamond cut data`);
      console.error(`Found in facet: ${selectorMap.get(abiSelector)}`);
      return false;
    }
  }

  return true;
}

export function generateDiamondCutDataFromDiff(
  onChainFacetInfo: { address: string, selectors: string[], bytecodeHash: string }[],
  localFacetInfo: { facet: string, selectors: string[], bytecodeHash: string }[],
) {
  const matchingFacetBytecodeHashes = onChainFacetInfo.filter(onChainFacet => {
    const localFacet = localFacetInfo.find(localFacet =>
      localFacet.bytecodeHash === onChainFacet.bytecodeHash
    )

    if (!localFacet) {
      return false
    }

    // Compare selectors arrays
    if (onChainFacet.selectors.length !== localFacet.selectors.length) {
      return false
    }

    const onChainSelectorsSet = new Set(onChainFacet.selectors)
    const localSelectorsSet = new Set(localFacet.selectors)

    if (!onChainFacet.selectors.every((selector: string) => localSelectorsSet.has(selector)) ||
      !localFacet.selectors.every((selector: string) => onChainSelectorsSet.has(selector))) {
      return false
    }

    return true
  }).map(facet => facet.bytecodeHash)


  const onChainFacetInfoWithDiff = onChainFacetInfo.filter(facet => !matchingFacetBytecodeHashes.includes(facet.bytecodeHash))

  const localFacetInfoWithDiff = localFacetInfo.filter(facet => !matchingFacetBytecodeHashes.includes(facet.bytecodeHash))

  const onChainSelectorsWithDiff = new Map()
  onChainFacetInfoWithDiff.forEach(facet => {
    facet.selectors.forEach((selector: string) => {
      onChainSelectorsWithDiff.set(selector, facet)
    })
  })

  const localSelectorsWithDiff = new Map()
  localFacetInfoWithDiff.forEach(facet => {
    facet.selectors.forEach((selector: string) => {
      localSelectorsWithDiff.set(selector, facet)
    })
  })

  // if a local facet is not already deployed, it needs to be deployed
  const facetsToDeploy = localFacetInfoWithDiff.map(facet => facet.facet)

  // Map from facet address to array of selectors that need to be added
  const addActions = new Map<string, string[]>()
  const replaceActions = new Map<string, string[]>()
  const removeActions: string[] = []

  // Group selectors by facet for add actions
  for (const [localSelector, facetInfo] of localSelectorsWithDiff) {
    if (!onChainSelectorsWithDiff.has(localSelector)) {
      const selectors = addActions.get(facetInfo.facet) || []
      selectors.push(localSelector)
      addActions.set(facetInfo.facet, selectors)
    } else {
      const selectors = replaceActions.get(facetInfo.facet) || []
      selectors.push(localSelector)
      replaceActions.set(facetInfo.facet, selectors)
    }
  }

  for (const [onChainSelector, _] of onChainSelectorsWithDiff) {
    if (!localSelectorsWithDiff.has(onChainSelector)) {
      removeActions.push(onChainSelector)
    }
  }

  return {
    add: Object.fromEntries(addActions),
    replace: Object.fromEntries(replaceActions),
    remove: removeActions,
    facetsToDeploy
  }
}

export async function getOnChainFacetInfo(
  hre: HardhatRuntimeEnvironment,
  exchangeProxy: string,
  l2Provider: ZkSyncProvider
) {
  const diamondLoupeFacet = new Contract(
    exchangeProxy,
    (await hre.artifacts.readArtifact("IDiamondLoupe")).abi,
    l2Provider
  )

  const facets = await diamondLoupeFacet.facets()
  const onChainFacetInfo = await Promise.all(facets.map(async (facet: { facetAddress: string; functionSelectors: string[] }) => {
    const facetCode = await l2Provider.getCode(facet.facetAddress)
    return {
      address: facet.facetAddress,
      selectors: facet.functionSelectors.slice().sort(),
      bytecodeHash: ethers.utils.hexlify(hashBytecode(facetCode))
    }
  }))

  return onChainFacetInfo
}

export async function getLocalFacetInfo(
  hre: HardhatRuntimeEnvironment,
) {
  const allLocalFacets = [
    // diamond cut is initialized at diamond migration
    // so not part of the exchange facet info
    {
      facet: "DiamondCutFacet",
      interface: "IDiamondCut"
    },
    ...ExchangeFacetInfos
  ]

  const localFacetInfo = await Promise.all(allLocalFacets.map(async (facetInfo) => {
    const facetArtifact = await hre.artifacts.readArtifact(facetInfo.facet)
    const facetInterfaceArtifact = await hre.artifacts.readArtifact(facetInfo.interface)
    const facetInterface = new ethers.utils.Interface(facetInterfaceArtifact.abi)
    return {
      facet: facetInfo.facet,
      selectors: Object.keys(facetInterface.functions).map((fn) => facetInterface.getSighash(fn)).slice().sort(),
      bytecodeHash: ethers.utils.hexlify(hashBytecode(facetArtifact.bytecode))
    }
  }))

  return localFacetInfo
}

export async function getLocalFacetSigHashToSigMapping(
  hre: HardhatRuntimeEnvironment,
) {
  const allLocalFacets = [
    // diamond cut is initialized at diamond migration
    // so not part of the exchange facet info
    {
      facet: "DiamondCutFacet",
      interface: "IDiamondCut"
    },
    ...ExchangeFacetInfos
  ]

  const sigHashToSigMapping: { [key: string]: string } = {}

  await Promise.all(allLocalFacets.map(async (facetInfo) => {
    const facetInterfaceArtifact = await hre.artifacts.readArtifact(facetInfo.interface)
    const facetInterface = new ethers.utils.Interface(facetInterfaceArtifact.abi)

    Object.keys(facetInterface.functions).forEach((fn) => {
      const sigHash = facetInterface.getSighash(fn)
      sigHashToSigMapping[sigHash] = fn
    })
  }))

  return sigHashToSigMapping
}

export async function validateFacetStorage(hre: HardhatRuntimeEnvironment) {
  const contractStorage = await getAbstractStorage(hre, "contracts/exchange/GRVTExchange.sol", "GRVTExchange");
  for (const facet of ExchangeFacetInfos) {
    const facetStorage = await getAbstractStorage(hre, facet.file, facet.facet);
    if (!(facetStorage.length === 0 || JSON.stringify(facetStorage) === JSON.stringify(contractStorage))) {
      throw new Error(`Inconsistent storage layout for facet ${facet.facet} in ${facet.file}`);
    }
  }
}

async function getAbstractStorage(hre: HardhatRuntimeEnvironment, file: string, contractName: string) {
  const buildInfo = await hre.artifacts.getBuildInfo(file + ":" + contractName);
  const storageWithContract = buildInfo?.output.contracts[file][contractName].storageLayout.storage;

  const storage = storageWithContract.map((item: any) => {
    return {
      label: item.label,
      offset: item.offset,
      size: item.size,
    }
  })

  return storage;
}

export async function enrichDiamondCutActionsWithSignatures(
  diamondCutData: {
    add: { [facet: string]: string[] },
    replace: { [facet: string]: string[] },
    remove: string[],
    facetsToDeploy: string[]
  },
  sigHashToSigMapping: { [key: string]: string }
) {
  const enrichActions = (actions: { [facet: string]: string[] }) => {
    const enriched: { [facet: string]: Array<[string, string]> } = {}

    for (const [facet, selectors] of Object.entries(actions)) {
      enriched[facet] = selectors.map(selector => [
        selector,
        sigHashToSigMapping[selector] || 'unknown'
      ])
    }

    return enriched
  }

  return {
    add: enrichActions(diamondCutData.add),
    replace: enrichActions(diamondCutData.replace),
    remove: diamondCutData.remove,
    facetsToDeploy: diamondCutData.facetsToDeploy
  }
}
