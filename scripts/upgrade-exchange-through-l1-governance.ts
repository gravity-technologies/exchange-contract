import { task } from "hardhat/config"

import * as fs from "fs"
import { ethers, Wallet as L1Wallet, BigNumber, Contract } from "ethers"
import { Wallet as L2Wallet } from "zksync-ethers"
import {
  createProviders,
  getL1ToL2TxInfo,
  encodeTransparentProxyUpgradeTo,
  getBaseToken,
  getGovernanceCalldata,
  scheduleAndExecuteGovernanceOp,
  getOnChainFacetInfo,
  getLocalFacetInfo,
  generateDiamondCutDataFromDiff,
  deployFromL1NoFactoryDepsNoConstructor,
  FacetCutAction,
} from "./utils"

import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import { Interface } from "ethers/lib/utils"

// deploy target on L2 first
task("deploy-l2-new-target", "Deploy new target on L2")
  .addParam("chainId", "chainId")
  .addParam("l1DeployerPrivateKey", "l1DeployerPrivateKey")
  .addOptionalParam(
    "l1GovernanceAdminPrivateKey",
    "l1GovernanceAdminPrivateKey (not required when useSafeMultisig is set)"
  )
  .addOptionalParam(
    "l1NonProxyGovernanceAdminPrivateKey",
    "l1NonProxyGovernanceAdminPrivateKey (not required when useSafeMultisig is set)"
  )
  .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
  .addParam("bridgeHub", "bridgeHub")
  .addParam("l1SharedBridge", "l1SharedBridge")
  .addParam("governance", "governance")
  .addParam("nonProxyGovernance", "nonProxyGovernance")
  .addParam("exchangeProxy", "exchangeProxy")
  .addParam("saltPreImage", "saltPreImage")
  .addFlag(
    "useSafeMultisig",
    "When set, do not send governance transactions. Instead, output a Safe multisig batch JSON " +
      "containing all governance steps (schedule + execute for both the proxy and non-proxy governance)."
  )
  .addOptionalParam(
    "safeTxOutputPath",
    "Path to write the Safe multisig batch JSON to (required when useSafeMultisig is set)"
  )
  .setAction(async (taskArgs, hre) => {
    const {
      chainId,
      l1DeployerPrivateKey,
      l1GovernanceAdminPrivateKey,
      l1NonProxyGovernanceAdminPrivateKey,
      l2OperatorPrivateKey,
      bridgeHub,
      l1SharedBridge,
      governance: proxyGovernance,
      nonProxyGovernance,
      exchangeProxy,
      saltPreImage,
      useSafeMultisig,
      safeTxOutputPath,
    } = taskArgs

    const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)
    const l2Operator = new L2Wallet(l2OperatorPrivateKey!, l2Provider)
    const l2Deployer = new Deployer(hre, l2Operator)

    // The governance-admin wallets are only needed to send the schedule/execute transactions.
    // In useSafeMultisig mode we only emit a Safe batch JSON, so they are not required.
    let l1GovernanceAdmin: L1Wallet | undefined
    let l1NonProxyGovernanceAdmin: L1Wallet | undefined

    if (useSafeMultisig) {
      if (!safeTxOutputPath) {
        throw new Error("safeTxOutputPath is required when useSafeMultisig is set")
      }
    } else {
      if (!l1GovernanceAdminPrivateKey || !l1NonProxyGovernanceAdminPrivateKey) {
        throw new Error(
          "l1GovernanceAdminPrivateKey and l1NonProxyGovernanceAdminPrivateKey are required when useSafeMultisig is not set"
        )
      }
      l1GovernanceAdmin = new L1Wallet(l1GovernanceAdminPrivateKey, l1Provider)
      l1NonProxyGovernanceAdmin = new L1Wallet(l1NonProxyGovernanceAdminPrivateKey, l1Provider)
    }

    const l1Deployer = new L1Wallet(l1DeployerPrivateKey!, l1Provider)

    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(saltPreImage))
    console.log("CREATE2 salt: ", salt)
    console.log("CREATE2 salt preimage: ", saltPreImage)

    const onChainFacetInfo = await getOnChainFacetInfo(hre, exchangeProxy, l2Provider)
    const localFacetInfo = await getLocalFacetInfo(hre)

    const {
      add: addCommands,
      replace: replaceCommands,
      remove: removeCommands,
      facetsToDeploy,
    } = generateDiamondCutDataFromDiff(onChainFacetInfo, localFacetInfo)

    const artifactsToDeploy = ["GRVTExchange", ...facetsToDeploy]

    console.log("Diamond cut data:")
    console.log("Add:", addCommands)
    console.log("Replace:", replaceCommands)
    console.log("Remove:", removeCommands)
    console.log("Artifacts to deploy:", artifactsToDeploy)

    const deployedContracts = new Map<string, string>()

    for (const artifactName of artifactsToDeploy) {
      const result = await deployFromL1NoFactoryDepsNoConstructor(
        hre,
        chainId,
        bridgeHub,
        l1SharedBridge,
        l1Deployer,
        l2Deployer,
        artifactName,
        salt
      )

      deployedContracts.set(artifactName, result.address)
    }

    const diamondCut = []
    for (const facet of Object.keys(addCommands)) {
      const address = deployedContracts.get(facet)!
      diamondCut.push({
        facetAddress: address,
        action: FacetCutAction.Add,
        functionSelectors: addCommands[facet],
      })
    }

    for (const facet of Object.keys(replaceCommands)) {
      const address = deployedContracts.get(facet)!
      diamondCut.push({
        facetAddress: address,
        action: FacetCutAction.Replace,
        functionSelectors: replaceCommands[facet],
      })
    }

    if (removeCommands.length > 0) {
      diamondCut.push({
        facetAddress: ethers.constants.AddressZero,
        action: FacetCutAction.Remove,
        functionSelectors: removeCommands,
      })
    }

    const exchangeContractAsDiamondCut = new Contract(
      exchangeProxy,
      (await hre.artifacts.readArtifact("IDiamondCut")).abi,
      l2Operator
    )

    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
    const exchangeInterface = new Interface(exchangeArtifact.abi)

    const grvtExchangeImplAddress = deployedContracts.get("GRVTExchange")!

    const baseToken = await getBaseToken(chainId, bridgeHub, l1Provider)
    const gasPrice = await l1Provider.getGasPrice()

    // schedule governance operation with 2 steps
    // approve l1SharedBridge to spend max amount of token
    // upgrade proxy to new target
    const proxyGovernanceCalls = [
      {
        target: await getBaseToken(chainId, bridgeHub, l1Provider),
        data: new ethers.utils.Interface(["function approve(address,uint256)"]).encodeFunctionData("approve", [
          l1SharedBridge,
          ethers.constants.MaxUint256,
        ]),
        value: 0,
      },
      await getL1ToL2TxInfo(
        chainId,
        bridgeHub,
        exchangeProxy,
        await encodeTransparentProxyUpgradeTo(hre, grvtExchangeImplAddress),
        ethers.constants.AddressZero,
        gasPrice.mul(10000), // use high gas price for L2 transaction to ensure the transaction is included
        BigNumber.from(1000000),
        l1Provider
      ),
    ]

    const proxyGovOperation = {
      calls: proxyGovernanceCalls,
      predecessor: ethers.constants.HashZero,
      salt: salt, // use the same salt for both create 2 and governance operation
    }

    const nonProxyGovernanceCalls = [
      {
        target: baseToken,
        data: new ethers.utils.Interface(["function approve(address,uint256)"]).encodeFunctionData("approve", [
          l1SharedBridge,
          ethers.constants.MaxUint256,
        ]),
        value: 0,
      },
      await getL1ToL2TxInfo(
        chainId,
        bridgeHub,
        exchangeProxy,
        exchangeContractAsDiamondCut.interface.encodeFunctionData("diamondCut", [
          diamondCut,
          ethers.constants.AddressZero,
          "0x",
        ]),
        ethers.constants.AddressZero,
        gasPrice.mul(10000), // use high gas price for L2 transaction to ensure the transaction is included
        BigNumber.from(5000000),
        l1Provider
      ),
    ]

    const nonProxyGovOperation = {
      calls: nonProxyGovernanceCalls,
      predecessor: ethers.constants.HashZero,
      salt: salt, // use the same salt for both create 2 and governance operation
    }

    if (useSafeMultisig) {
      // Instead of sending the schedule/execute transactions, emit a single Safe multisig batch
      // JSON that combines both scheduleAndExecuteGovernanceOp flows (proxy + non-proxy governance)
      // into one batch. This assumes a single Safe owns both governance contracts.
      const proxyGovCalldata = await getGovernanceCalldata(proxyGovOperation, l1Provider)
      const nonProxyGovCalldata = await getGovernanceCalldata(nonProxyGovOperation, l1Provider)

      // Governance lives on L1, so the Safe batch targets the L1 chain.
      const l1ChainId = (await l1Provider.getNetwork()).chainId

      const emptyTxInputs = { contractMethod: null, contractInputsValues: null }
      const safeBatch = {
        version: "1.0",
        chainId: l1ChainId.toString(),
        createdAt: Date.now(),
        meta: {
          name: "GRVT Exchange Upgrade",
          description:
            "Schedule and execute the proxy and non-proxy governance operations to upgrade the GRVT exchange contract",
          txBuilderVersion: "1.16.5",
          createdFromSafeAddress: "",
          createdFromOwnerAddress: "",
        },
        // Order matches the non-Safe flow: proxy schedule + execute, then non-proxy schedule + execute.
        transactions: [
          { to: proxyGovernance, value: "0", data: proxyGovCalldata.scheduleTransparent, ...emptyTxInputs },
          { to: proxyGovernance, value: "0", data: proxyGovCalldata.execute, ...emptyTxInputs },
          { to: nonProxyGovernance, value: "0", data: nonProxyGovCalldata.scheduleTransparent, ...emptyTxInputs },
          { to: nonProxyGovernance, value: "0", data: nonProxyGovCalldata.execute, ...emptyTxInputs },
        ],
      }

      const safeBatchJson = JSON.stringify(safeBatch, null, 2)
      fs.writeFileSync(safeTxOutputPath, safeBatchJson)

      console.log("useSafeMultisig is set: governance transactions were NOT sent.")
      console.log("Safe multisig batch JSON written to: ", safeTxOutputPath)
      console.log(safeBatchJson)

      return
    }

    const { scheduleTxReceipt: proxyGovScheduleTxReceipt, executeTxReceipt: proxyGovExecuteTxReceipt } =
      await scheduleAndExecuteGovernanceOp(proxyGovernance, l1GovernanceAdmin!, proxyGovOperation)

    console.log("Proxy governance operation schedule txhash: ", proxyGovScheduleTxReceipt.transactionHash)
    console.log("Proxy governance operation schedule status: ", proxyGovScheduleTxReceipt.status)

    console.log("Proxy governance operation execution txhash: ", proxyGovExecuteTxReceipt.transactionHash)
    console.log("Proxy governance operation execution status: ", proxyGovExecuteTxReceipt.status)

    console.log("Proxy governance calldata: ", await getGovernanceCalldata(proxyGovOperation, l1Provider))

    const { scheduleTxReceipt: nonProxyGovScheduleTxReceipt, executeTxReceipt: nonProxyGovExecuteTxReceipt } =
      await scheduleAndExecuteGovernanceOp(nonProxyGovernance, l1NonProxyGovernanceAdmin!, nonProxyGovOperation)

    console.log("Non-proxy governance operation schedule txhash: ", nonProxyGovScheduleTxReceipt.transactionHash)
    console.log("Non-proxy governance operation schedule status: ", nonProxyGovScheduleTxReceipt.status)

    console.log("Non-proxy governance operation execution txhash: ", nonProxyGovExecuteTxReceipt.transactionHash)
    console.log("Non-proxy governance operation execution status: ", nonProxyGovExecuteTxReceipt.status)

    console.log("Non-proxy governance calldata: ", await getGovernanceCalldata(nonProxyGovOperation, l1Provider))
  })
