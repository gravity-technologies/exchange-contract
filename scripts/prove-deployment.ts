import { task } from "hardhat/config"
import { BigNumber, ethers } from "ethers"
import * as fs from "fs"
import { execSync } from "child_process"

import { L2SharedBridgeFactory } from "../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { computeL2Create2Address, computeL2Create2AddressFromBytecodeHash, createProviders } from "./utils"
import { IBridgehubFactory } from "../lib/era-contracts/l1-contracts/typechain/IBridgehubFactory"
import { GovernanceFactory } from "../lib/era-contracts/l1-contracts/typechain/GovernanceFactory"
import { IZkSyncHyperchainFactory } from "../lib/era-contracts/l1-contracts/typechain/IZkSyncHyperchainFactory"
import { IZkSyncHyperchain } from "../lib/era-contracts/l1-contracts/typechain/IZkSyncHyperchain"
import { Governance } from "../lib/era-contracts/l1-contracts/typechain/Governance"

import { applyL1ToL2Alias, hashBytecode } from "zksync-web3/build/src/utils"
import { Artifact, HardhatRuntimeEnvironment } from "hardhat/types"
import { IBridgehub } from "../lib/era-contracts/l1-contracts/typechain/IBridgehub"
import { Interface } from "ethers/lib/utils"
import { DepositProxy__factory } from "../typechain-types"

export const BOOTLOADER_FORMAL_ADDRESS = "0x0000000000000000000000000000000000008001"
export const DEPLOYER_SYSTEM_CONTRACT_ADDRESS = "0x0000000000000000000000000000000000008006"

interface Proof {
  chainId: number
  bridgeHub: string
  bridgeProxyAddress: string
  grvtGovernanceAddress: string
  deployment: DeploymentProof
  upgrades: UpgradeProof[]
}

interface DeploymentProof {
  commit: string
  deployer: string
  salt: string
  admin: string
  initializeConfigSigner: string
  chainSubmitter: string
  depositProxyBeaconOwner: string
  implementationDeployment: PriorityOpProof
  proxyDeployment: PriorityOpProof
}

interface PriorityOpProof {
  l1TxHash: string
  l2TxHash: string
  l2BatchNumber: number
  l2MessageIndex: number
  l2TxNumberInBatch: number
  merkleProof: string[]
  status: number
}

interface UpgradeProof {}

const bridgeProxyABI = ["function l2DepositProxyAddressDerivationParams() view returns (address,bytes32,address)"]

task("prove-deployment", "Prove deployment and upgrade history")
  .addParam("l1RpcEndpoint", "Ethereum L1 RPC endpoint", "https://eth.drpc.org")
  .addParam("proofFile", "Proof file", "./proof-mainnet.json")
  .setAction(async (taskArgs, hre) => {
    const { l1RpcEndpoint, proofFile } = taskArgs
    const proof = JSON.parse(fs.readFileSync(proofFile, "utf8")) as Proof

    const l1Provider = new ethers.providers.JsonRpcProvider(l1RpcEndpoint)

    const bridgeProxy = new ethers.Contract(proof.bridgeProxyAddress, bridgeProxyABI, l1Provider)
    const bridgehub = IBridgehubFactory.connect(proof.bridgeHub, l1Provider)
    const governance = GovernanceFactory.connect(proof.grvtGovernanceAddress, l1Provider)
    const hyperchainAddress = await bridgehub.getHyperchain(proof.chainId)

    const hyperchain = IZkSyncHyperchainFactory.connect(hyperchainAddress, l1Provider)

    // get deposit proxy address derivation params from the bridge proxy
    const [exchangeAddress, beaconProxyBytecodeHash, depositProxyBeaconAddress] =
      await bridgeProxy.l2DepositProxyAddressDerivationParams()

    const {
      proxyArtifact: proxyArtifactAtDeployment,
      exchangeArtifact: exchangeArtifactAtDeployment,
      beaconProxyArtifact: beaconProxyArtifactAtDeployment,
      depositProxyArtifact: depositProxyArtifactAtDeployment,
      depositProxyBeaconArtifact: depositProxyBeaconArtifactAtDeployment,
    } = await getArtifactsAtCommit(hre, proof.deployment.commit)

    const exchangeCodehashAtDeployment = getBytecodeHash(exchangeArtifactAtDeployment)
    const proxyCodehashAtDeployment = getBytecodeHash(proxyArtifactAtDeployment)
    const beaconProxyBytecodeHashAtDeployment = getBytecodeHash(beaconProxyArtifactAtDeployment)
    const depositProxyBytecodeHashAtDeployment = getBytecodeHash(depositProxyArtifactAtDeployment)
    const depositProxyBeaconBytecodeHashAtDeployment = getBytecodeHash(depositProxyBeaconArtifactAtDeployment)

    // check that beaconProxyBytecodeHash matches value in bridge proxy
    if (beaconProxyBytecodeHashAtDeployment !== beaconProxyBytecodeHash) {
      throw new Error("Beacon proxy bytecode hash mismatch")
    }
    console.log("✅ beacon proxy bytecode hash at deployment commit matches value in bridge proxy")

    const expectedExchangeImplAddress = computeL2Create2AddressFromBytecodeHash(
      proof.deployment.deployer,
      exchangeCodehashAtDeployment,
      ethers.utils.arrayify("0x"),
      proof.deployment.salt
    )

    const exchangeInitializeData = new Interface(exchangeArtifactAtDeployment.abi).encodeFunctionData("initialize", [
      proof.deployment.admin,
      proof.deployment.chainSubmitter,
      proof.deployment.initializeConfigSigner,
      proof.deployment.depositProxyBeaconOwner,
      beaconProxyBytecodeHashAtDeployment,
    ])

    const exchangeProxyConstructorData = ethers.utils.arrayify(
      new ethers.utils.AbiCoder().encode(
        ["address", "address", "bytes"],
        // TransparentUpgradeableProxy admin is the L1 alias of the governance contract
        // This means contract upgrades are only possible through the governance contract
        [expectedExchangeImplAddress, applyL1ToL2Alias(proof.grvtGovernanceAddress), exchangeInitializeData]
      )
    )

    const expectedExchangeProxyAddress = computeL2Create2AddressFromBytecodeHash(
      proof.deployment.deployer,
      proxyCodehashAtDeployment,
      exchangeProxyConstructorData,
      proof.deployment.salt
    )

    if (expectedExchangeProxyAddress !== exchangeAddress) {
      throw new Error("🚨 Expected exchange proxy address does not match value in bridge proxy")
    }

    console.log("✅ Expected exchange proxy address matches value in bridge proxy")

    const expectedDepositProxyBeaconAddress = computeL2Create2AddressFromBytecodeHash(
      expectedExchangeProxyAddress,
      depositProxyBeaconBytecodeHashAtDeployment,
      ethers.utils.arrayify(
        new ethers.utils.AbiCoder().encode(
          ["address"],
          [
            computeL2Create2AddressFromBytecodeHash(
              expectedExchangeProxyAddress,
              depositProxyBytecodeHashAtDeployment,
              ethers.utils.arrayify("0x"),
              ethers.constants.HashZero
            ),
          ]
        )
      ),
      ethers.constants.HashZero
    )

    if (expectedDepositProxyBeaconAddress !== depositProxyBeaconAddress) {
      throw new Error("🚨 Expected deposit proxy beacon address does not match value in bridge proxy")
    }

    console.log("✅ Expected deposit proxy beacon address matches value in bridge proxy")

    const deployerSystemContracts = new Interface(
      hre.artifacts.readArtifactSync(
        "lib/era-contracts/l2-contracts/contracts/L2ContractHelper.sol:IContractDeployer"
      ).abi
    )

    await proveCreate2Deployment(
      proof.chainId,
      l1Provider,
      hyperchain,
      bridgehub,
      deployerSystemContracts,
      proof.deployment.implementationDeployment,
      expectedExchangeImplAddress,
      "Exchange Contract Implementation Deployment"
    )

    await proveCreate2Deployment(
      proof.chainId,
      l1Provider,
      hyperchain,
      bridgehub,
      deployerSystemContracts,
      proof.deployment.proxyDeployment,
      expectedExchangeProxyAddress,
      "Exchange Contract Proxy Deployment"
    )

    await checkUpgrades(proof, hyperchain, governance, l1Provider)
  })

async function proveCreate2Deployment(
  chainId: number,
  l1Provider: ethers.providers.JsonRpcProvider,
  hyperchain: IZkSyncHyperchain,
  bridgehub: IBridgehub,
  deployerSystemContracts: Interface,
  proof: PriorityOpProof,
  expectedAddress: string,
  name: string
) {
  const deploymentRequestEvent = await provePriorityOperationIsSuccessful(
    chainId,
    l1Provider,
    hyperchain,
    bridgehub,
    proof,
    name
  )

  const { from, to, data } = deploymentRequestEvent.args.transaction

  if (bigIntToAddress(to) !== DEPLOYER_SYSTEM_CONTRACT_ADDRESS) {
    throw new Error(`Expected ${name} to be a call to the deployer system contract`)
  }

  const create2Calldata = deployerSystemContracts.parseTransaction({ data })

  if (create2Calldata.name !== "create2") {
    throw new Error(`Expected ${name} to be a create2 deployment`)
  }

  const { _input, _salt, _bytecodeHash } = create2Calldata.args

  const actualAddress = computeL2Create2AddressFromBytecodeHash(from, _bytecodeHash, _input, _salt)

  if (actualAddress !== expectedAddress) {
    throw new Error(`Expected ${name} to deploy to ${expectedAddress}, but deployed to ${actualAddress}`)
  }

  console.log(`✅ ${name} create2 tx proven successful`)
}

function bigIntToAddress(bigInt: BigNumber) {
  return ethers.utils.getAddress(ethers.utils.hexZeroPad(bigInt.toHexString(), 20))
}

async function provePriorityOperationIsSuccessful(
  chainId: number,
  l1Provider: ethers.providers.JsonRpcProvider,
  hyperchain: IZkSyncHyperchain,
  bridgehub: IBridgehub,
  proof: PriorityOpProof,
  name: string
) {
  if (proof.status !== 1) {
    throw new Error(`${name} tx failed`)
  }

  const txReceipt = await l1Provider.getTransactionReceipt(proof.l1TxHash)
  const priorityRequestEvents = txReceipt.logs
    .filter((l) => isNewPriorityRequestEvent(l, hyperchain))
    .map((l) => hyperchain.interface.parseLog(l))
    .filter((l) => l.args.txHash === proof.l2TxHash)

  if (priorityRequestEvents.length !== 1) {
    throw new Error(`Expected exactly one priority request event for ${name} tx`)
  }

  const isValid = await bridgehub.proveL1ToL2TransactionStatus(
    chainId,
    proof.l2TxHash,
    proof.l2BatchNumber,
    proof.l2MessageIndex,
    proof.l2TxNumberInBatch,
    proof.merkleProof,
    proof.status
  )

  if (!isValid) {
    throw new Error(`${name} tx failed`)
  }

  return priorityRequestEvents[0]
}

async function getArtifactsAtCommit(hre: HardhatRuntimeEnvironment, commitHash: string) {
  return await withCommit(commitHash, async () => {
    const proxyArtifact = await hre.artifacts.readArtifact("TransparentUpgradeableProxy")
    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
    const beaconProxyArtifact = await hre.artifacts.readArtifact("BeaconProxy")
    const depositProxyArtifact = await hre.artifacts.readArtifact("DepositProxy")
    const depositProxyBeaconArtifact = await hre.artifacts.readArtifact("UpgradeableBeacon")
    return { proxyArtifact, exchangeArtifact, beaconProxyArtifact, depositProxyArtifact, depositProxyBeaconArtifact }
  })
}

function getBytecodeHash(artifact: Artifact) {
  return ethers.utils.hexlify(hashBytecode(artifact.bytecode))
}

async function withCommit<T>(commitHash: string, fn: () => Promise<T>): Promise<T> {
  const currentBranch = execSync("git branch --show-current").toString().trim()
  let result: T

  if (!currentBranch) {
    throw new Error("Must be on a branch to perform this operation")
  }

  try {
    console.log("Checking out commit", commitHash)
    execSync(`git checkout ${commitHash}`, { stdio: "ignore" })
    console.log("Compiling contracts")
    execSync("yarn compile", { stdio: "ignore" })
    result = await fn()
  } finally {
    console.log("Back to branch", currentBranch)
    execSync(`git checkout ${currentBranch}`, { stdio: "ignore" })
  }

  return result
}

// only check that there has been no upgrades
async function checkUpgrades(
  proof: Proof,
  hyperchain: IZkSyncHyperchain,
  governance: Governance,
  l1Provider: ethers.providers.JsonRpcProvider
) {
  if (proof.upgrades.length > 0) {
    throw new Error("Upgrades are not supported yet")
  }

  const opExecutedEvents = await governance.queryFilter(governance.filters.OperationExecuted(null))
  const txsWithOpExecuted = await Promise.all(
    opExecutedEvents.map((e) => l1Provider.getTransactionReceipt(e.transactionHash))
  )
  const priorityOpsEventsFromGovernance = txsWithOpExecuted.flatMap((tx) =>
    tx.logs.filter((l) => isNewPriorityRequestEvent(l, hyperchain))
  )

  if (priorityOpsEventsFromGovernance.length !== 0) {
    throw new Error("🚨 Expected no priority operations from governance, contract might have been upgraded")
  }

  console.log("✅ No priority operations from governance - contract has not been upgraded")
}

function isNewPriorityRequestEvent(log: ethers.providers.Log, hyperchain: IZkSyncHyperchain) {
  return (
    log.address === hyperchain.address && log.topics[0] === hyperchain.interface.getEventTopic("NewPriorityRequest")
  )
}

task("get-priority-op-proof", "Get priority operation proof")
  .addParam("l2TxHash", "L2 transaction hash")
  .setAction(async (taskArgs, hre) => {
    const { l2TxHash } = taskArgs
    const { l2Provider } = createProviders(hre.config.networks, hre.network)

    const txReceipt = await l2Provider.getTransactionReceipt(l2TxHash)
    const l2ToL1Logs = txReceipt.l2ToL1Logs.filter((l) => l.sender === BOOTLOADER_FORMAL_ADDRESS)

    if (l2ToL1Logs.length !== 1) {
      throw new Error("Expected exactly one L2->L1 log from bootloader")
    }
    const l2ToL1Log = l2ToL1Logs[0]

    const proofRes = await l2Provider.getLogProof(l2ToL1Log.transactionHash, l2ToL1Log.logIndex)
    console.log(
      JSON.stringify(
        {
          l2TxHash: l2ToL1Log.transactionHash,
          l2BatchNumber: l2ToL1Log.l1BatchNumber,
          l2MessageIndex: proofRes!.id,
          l2TxNumberInBatch: l2ToL1Log.txIndexInL1Batch,
          merkleProof: proofRes!.proof,
          status: txReceipt.status,
        },
        null,
        2
      )
    )
  })
