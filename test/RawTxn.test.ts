import { expect } from "chai"
import { Contract } from "zksync-ethers"
import { Wallet, Provider, utils } from "zksync-ethers"
import { ethers, Wallet as W1 } from "ethers"
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
  var w1 = new W1(LOCAL_RICH_WALLETS[0].privateKey)
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
      // const data2 = ethers.utils.hexlify(txData)
      // var response = await processRawTransaction(contract, data2)
      var response = await processRawTransaction(contract, txData)
      console.log(response)
    })
  })

  async function processRawTransaction(contract: Contract, data: string) {
    // var provider = contract.provider
    console.log("contract.address:", contract.address)
    var provider = getProvider()
    var tx: ethers.providers.TransactionRequest = {
      // type: utils.EIP712_TX_TYPE,
      to: contract.address,
      gasLimit: 2100000,
      data: data,
    }
    w1 = w1.connect(provider)
    const resp = await w1.sendTransaction(tx)
    console.log("waiting")
    await resp.wait()
    console.log("waiting: over")
  }
})
