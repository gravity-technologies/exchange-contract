import { task } from "hardhat/config"
import { Wallet as L2Wallet, Provider as L2Provider } from "zksync-ethers"
import { ethers } from "ethers"
import { Interface } from "ethers/lib/utils"

import { L2SharedBridgeFactory } from "../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { IBridgehubFactory } from "../lib/era-contracts/l1-contracts/typechain/IBridgehubFactory"
import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import { createProviders } from "./utils"
import { bridge } from "../typechain-types/lib/era-contracts/l2-contracts/contracts"

task("set-exchange-address", "Set exchange address")
  .addParam("l2SharedBridge", "l2SharedBridge")
  .addParam("exchange", "exchange")
  .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
  .setAction(async (taskArgs, hre) => {
    const { l2SharedBridge: l2SharedBridgeAddr, exchange, l2OperatorPrivateKey } = taskArgs
    const l2SharedBridge = L2SharedBridgeFactory.connect(
      l2SharedBridgeAddr,
      new L2Wallet(l2OperatorPrivateKey, new L2Provider(hre.network.config.url))
    )
    const tx = await l2SharedBridge.setExchangeAddress(exchange)
    console.log("setExchangeAddress transaction hash:", tx.hash)
    console.log("Transaction was mined in block:", (await tx.wait()).blockNumber)
  })

task("prove-exchange-address", "Prove exchange address")
  .addParam("bridgeHub", "bridgeHub")
  .addParam("chainId", "chainId")
  .addParam("l2SharedBridge", "l2SharedBridge")
  .setAction(async (taskArgs, hre) => {
    const { bridgeHub: bridgehubAddress, chainId, l2SharedBridge: l2SharedBridgeAddress } = taskArgs
    const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)

    const rx = await l2Provider.getTransactionReceipt(
      "0xc7665b97cc6dc647ec77ab82f1ed8e117e611d7f6940ed1649af313404860cfb"
    )
    if (rx.l2ToL1Logs.length !== 1) {
      throw new Error("Expected exactly one log")
    }

    const l2ToL1Log = rx.l2ToL1Logs[0]

    const proofRes = await l2Provider.getMessageProof(rx.blockNumber, l2SharedBridgeAddress, l2ToL1Log.value)

    const proof = proofRes!.proof

    // check against an actual exchange address
    const l2SharedBridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, l2Provider)

    const bridgehub = IBridgehubFactory.connect(bridgehubAddress, l1Provider)
    const isProofValid = await bridgehub.proveL2MessageInclusion(
      chainId,
      rx.l1BatchNumber,
      l2ToL1Log.logIndex,
      {
        txNumberInBatch: rx.l1BatchTxIndex,
        sender: l2SharedBridgeAddress,
        data: ethers.utils.solidityPack(
          ["bytes4", "address"],
          [l2SharedBridge.interface.getSighash("setExchangeAddress"), "0x80e51ac583e99ec0705cd51b5820e64d211bf617"]
        ),
      },
      proof
    )

    console.log(isProofValid)
  })
