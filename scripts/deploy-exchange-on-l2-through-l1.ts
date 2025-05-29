import { ethers, Wallet as L1Wallet, providers as l1Providers } from "ethers"

import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import { Wallet as L2Wallet, Provider as L2Provider } from "zksync-ethers"

import { ADDRESS_ONE, create2DeployFromL1NoFactoryDeps, computeL2Create2Address, createProviders, approveL1SharedBridgeIfNeeded } from "./utils"
import { task } from "hardhat/config"
import { applyL1ToL2Alias, hashBytecode } from "zksync-web3/build/src/utils"
import { Interface } from "ethers/lib/utils"

task("deploy-exchange-on-l2-through-l1", "Deploy exchange on L2 through L1")
  .addParam("l1DeployerPrivateKey", "l1DeployerPrivateKey")
  .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
  .addParam("governance", "governance")
  .addParam("bridgeHub", "bridgeHub")
  .addParam("initializeConfigSigner", "initializeConfigSigner")
  .addParam("admin", "admin")
  .addParam("chainSubmitter", "chainSubmitter")
  .addParam("l1SharedBridge", "l1SharedBridge")
  .addParam("depositProxyBeaconOwner", "depositProxyBeaconOwner")
  .addParam("chainId", "chainId")
  .addParam("saltPreImage", "saltPreImage")
  .setAction(async (taskArgs, hre) => {
    const {
      l1DeployerPrivateKey,
      l2OperatorPrivateKey,
      governance,
      bridgeHub,
      l1SharedBridge,
      depositProxyBeaconOwner,
      initializeConfigSigner,
      admin,
      chainSubmitter,
      chainId,
      saltPreImage,
    } = taskArgs

    const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)
    const l2Operator = new L2Wallet(l2OperatorPrivateKey!, l2Provider)
    const l2Deployer = new Deployer(hre, l2Operator)

    const l1Deployer = new L1Wallet(l1DeployerPrivateKey!, l1Provider)

    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(saltPreImage))
    console.log("CREATE2 salt: ", salt)
    console.log("CREATE2 salt preimage: ", saltPreImage)

    // deploy an instance of the exchange and TUP to L2 only to save the code on chain
    // actual deployment to be done through L1
    const exchangeArtifact = await l2Deployer.loadArtifact("GRVTExchange")
    const exchangeImpl = await l2Deployer.deploy(exchangeArtifact, [])
    const exchangeCodehash = hashBytecode(exchangeArtifact.bytecode)

    const beaconArtifact = await l2Deployer.loadArtifact("UpgradeableBeacon")
    const beaconInstance = await l2Deployer.deploy(beaconArtifact, [exchangeImpl.address])
    const beaconCodehash = hashBytecode(beaconArtifact.bytecode)

    const beaconProxyArtifact = await l2Deployer.loadArtifact("BeaconProxy")
    await l2Deployer.deploy(beaconProxyArtifact, [
      beaconInstance.address,
      "0x",
    ])
    const beaconProxyCodehash = hashBytecode(beaconProxyArtifact.bytecode)

    const exchangeInitializeData = new Interface(exchangeArtifact.abi).encodeFunctionData("initialize", [admin, chainSubmitter, initializeConfigSigner, depositProxyBeaconOwner, beaconProxyCodehash])
    const tupArtifact = await l2Deployer.loadArtifact("TransparentUpgradeableProxy")
    await l2Deployer.deploy(tupArtifact, [
      exchangeImpl.address,
      ADDRESS_ONE,
      exchangeInitializeData,
    ])
    const tupCodehash = hashBytecode(tupArtifact.bytecode)

    const exchangeImplConstructorData = ethers.utils.arrayify("0x")
    const expectedExchangeImplAddress = computeL2Create2Address(
      l1Deployer.address,
      exchangeArtifact.bytecode,
      exchangeImplConstructorData,
      salt
    )

    const exchangeProxyConstructorData = ethers.utils.arrayify(
      new ethers.utils.AbiCoder().encode(
        ["address", "address", "bytes"],
        [
          expectedExchangeImplAddress,
          applyL1ToL2Alias(governance),
          exchangeInitializeData,
        ]
      )
    )

    const expectedExchangeProxyAddress = computeL2Create2Address(
      l1Deployer.address,
      tupArtifact.bytecode,
      exchangeProxyConstructorData,
      salt
    )

    console.log("L1 deployer address", l1Deployer.address)
    console.log("Exchange codehash: ", ethers.utils.hexlify(exchangeCodehash))
    console.log("TUP codehash: ", ethers.utils.hexlify(tupCodehash))
    console.log("Beacon codehash: ", ethers.utils.hexlify(beaconCodehash))
    console.log("Beacon proxy codehash: ", ethers.utils.hexlify(beaconProxyCodehash))
    console.log("Expected exchange impl address: ", expectedExchangeImplAddress)
    console.log("Expected exchange proxy address: ", expectedExchangeProxyAddress)

    await approveL1SharedBridgeIfNeeded(chainId, bridgeHub, l1SharedBridge, l1Deployer)

    // deploy exchange and proxy
    const exchangeImplDepTx = await create2DeployFromL1NoFactoryDeps(
      hre,
      chainId,
      bridgeHub,
      l1SharedBridge,
      l1Deployer,
      exchangeArtifact.bytecode,
      exchangeImplConstructorData,
      salt,
      1000000
    )
    const exchangeImplDepTxReceipt = await exchangeImplDepTx.wait()
    console.log("Exchange impl deployment tx hash: ", exchangeImplDepTx.hash)
    console.log("Exchange impl deployment stauts: ", exchangeImplDepTxReceipt.status)

    const exchangeProxyDepTx = await create2DeployFromL1NoFactoryDeps(
      hre,
      chainId,
      bridgeHub,
      l1SharedBridge,
      l1Deployer,
      tupArtifact.bytecode,
      exchangeProxyConstructorData,
      salt,
      5000000
    )
    const exchangeProxyDepTxReceipt = await exchangeProxyDepTx.wait()
    console.log("Exchange impl deployment tx hash: ", exchangeProxyDepTx.hash)
    console.log("Exchange impl deployment stauts: ", exchangeProxyDepTxReceipt.status)
  })
