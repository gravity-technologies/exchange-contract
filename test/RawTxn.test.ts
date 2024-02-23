import { expect } from "chai"
import { Contract } from "zksync-ethers"
import { Wallet, Provider, utils } from "zksync-ethers"
import { ethers } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getProvider, getWallet } from "../deploy/utils"
import * as fs from "fs"

import { txRequestDefault } from "./api"
import { AccPerm, Signature } from "./type"
import { expectToThrowAsync, getDeployerWallet, nonce, wallet } from "./util"
import { genCreateAccountSig } from "./signature"

describe.only("API - Raw Transactions Prototype", function () {
  let contract: Contract
  let snapshotId: string
  var w1 = wallet()
  let ts: number

  before(async () => {
    const deployingWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchange", [], { wallet: deployingWallet, silent: true, noVerify: true })
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
    ts = 1
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  describe("Create Account Raw Transaction", function () {
    it("should pass", async function () {
      const txData =
        "0x86db00e100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0ffee254729296a45a3885639ac7e10f9d54979000000000000000000000000c0ffee254729296a45a3885639ac7e10f9d5497912345678901234567890123456789012345678901234567890123456789012341234567890123456789012345678901234567890123456789012345678901234000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
      // const data2 = ethers.utils.hexlify(txData)
      // var response = await processRawTransaction(contract, data2)
      var response = await processRawTransaction(contract, txData)
      console.log(response)
    })
  })

  async function processRawTransaction(contract: Contract, data: string) {
    // var provider = contract.provider
    var provider = getProvider()
    var tx: ethers.providers.TransactionRequest = {
      type: utils.EIP712_TX_TYPE,
      to: contract.address,
      gasLimit: 210000,
      data: data,
    }
    w1 = w1.connect(provider)
    // const txn = await w1.signTransaction(tx)
    // w1 = w1.connect(provider)
    await w1.sendTransaction(tx)
  }
})
