import { task } from "hardhat/config"

import { ethers, Wallet as L1Wallet, providers as l1Providers, BigNumber } from "ethers"
import { Wallet as L2Wallet, Provider as L2Provider } from "zksync-ethers"
import {
  ADDRESS_ONE,
  create2DeployFromL1NoFactoryDeps,
  computeL2Create2Address,
  createProviders,
  getL1ToL2TxInfo,
  getTransparentProxyUpgradeCalldata,
  getBaseToken,
  getGovernanceCalldata,
  scheduleAndExecuteGovernanceOp,
} from "./utils"

import { hashBytecode } from "zksync-web3/build/src/utils"

import { Deployer } from "@matterlabs/hardhat-zksync-deploy"

// deploy target on L2 first
task("deploy-l2-new-target", "Deploy new target on L2")
  .addParam("chainId", "chainId")
  .addParam("l1DeployerPrivateKey", "l1DeployerPrivateKey")
  .addParam("l1GovernanceAdminPrivateKey", "l1GovernanceAdminPrivateKey")
  .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
  .addParam("bridgeHub", "bridgeHub")
  .addParam("l1SharedBridge", "l1SharedBridge")
  .addParam("governance", "governance")
  .addParam("exchangeProxy", "exchangeProxy")
  .addParam("saltPreImage", "saltPreImage")
  .setAction(async (taskArgs, hre) => {
    const {
      chainId,
      l1DeployerPrivateKey,
      l1GovernanceAdminPrivateKey,
      l2OperatorPrivateKey,
      bridgeHub,
      l1SharedBridge,
      governance,
      exchangeProxy,
      saltPreImage,
    } = taskArgs

    const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)
    const l2Operator = new L2Wallet(l2OperatorPrivateKey!, l2Provider)
    const l2Deployer = new Deployer(hre, l2Operator)

    const l1GovernanceAdmin = new L1Wallet(l1GovernanceAdminPrivateKey!, l1Provider)
    const l1Deployer = new L1Wallet(l1DeployerPrivateKey!, l1Provider)

    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(saltPreImage))
    console.log("CREATE2 salt: ", salt)
    console.log("CREATE2 salt preimage: ", saltPreImage)

    // TODO: add balance check(l1Deployer, l1GovernanceAdmin, governance)

    // deploy an instance of the exchange to L2 only to save the code on chain
    // actual deployment to be done through L1
    const exchangeArtifact = await l2Deployer.loadArtifact("GRVTExchange")
    const exchangeCodehash = hashBytecode(exchangeArtifact.bytecode)
    const exchangeImpl = await l2Deployer.deploy(exchangeArtifact, [])

    const newExchangeImplConstructorData = ethers.utils.arrayify("0x")
    const expectedNewExchangeImplAddress = computeL2Create2Address(
      l1Deployer.address,
      exchangeArtifact.bytecode,
      newExchangeImplConstructorData,
      salt
    )
    console.log("Exchange codehash: ", ethers.utils.hexlify(exchangeCodehash))
    console.log("Expected exchange impl address: ", expectedNewExchangeImplAddress)

    // deploy an instance of the exchange impl with CREATE2
    const newExchangeImplDepTx = await create2DeployFromL1NoFactoryDeps(
      hre,
      chainId,
      bridgeHub,
      l1SharedBridge,
      l1Deployer,
      exchangeArtifact.bytecode,
      newExchangeImplConstructorData,
      salt,
      1000000
    )
    const newExchangeImplDepTxReceipt = await newExchangeImplDepTx.wait()

    console.log("Exchange impl deployment tx hash: ", newExchangeImplDepTx.hash)
    console.log("Exchange impl deployment stauts: ", newExchangeImplDepTxReceipt.status)

    // schedule governance operation with 2 steps
    // approve l1SharedBridge to spend max amount of token
    // upgrade proxy to new target
    const gasPrice = await l1Provider.getGasPrice()
    const governanceCalls = [
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
        await getTransparentProxyUpgradeCalldata(hre, expectedNewExchangeImplAddress),
        ethers.constants.AddressZero,
        gasPrice.mul(100), // use high gas price for L2 transaction to ensure the transaction is included
        BigNumber.from(1000000),
        l1Provider
      ),
    ]

    const operation = {
      calls: governanceCalls,
      predecessor: ethers.constants.HashZero,
      salt: salt, // use the same salt for both create 2 and governance operation
    }

    const { scheduleTxReceipt, executeTxReceipt } = await scheduleAndExecuteGovernanceOp(
      governance,
      l1GovernanceAdmin,
      operation
    )

    console.log("Governance operation schedule txhash: ", scheduleTxReceipt.transactionHash)
    console.log("Governance operation schedule status: ", scheduleTxReceipt.status)

    console.log("Governance operation execution txhash: ", executeTxReceipt.transactionHash)
    console.log("Governance operation execution status: ", executeTxReceipt.status)

    console.log("calldata: ", await getGovernanceCalldata(operation, l1Provider))
  })
