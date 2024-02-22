import { expect } from "chai"
import { Contract, ethers } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../deploy/utils"
import * as fs from "fs"

import { txRequestDefault } from "./api"
import { AccPerm, Signature } from "./type"
import { expectToThrowAsync, getDeployerWallet, nonce, wallet } from "./util"
import { genCreateAccountSig } from "./signature"

describe.only("API - Raw Transactions Prototype", function () {
  let contract: Contract
  let snapshotId: string
  const w1 = wallet()
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
      const salt = nonce()
      const sig = genCreateAccountSig(w1, w1.address, salt)
      const abi = getTheAbi()
      //   for (let i = 0; i < abi?.length; i++) {
      //     if abi?[i].name === "createAccount" {
      //         console.log(`abi[i]`, abi[i])
      //         }
      //     }

      const abi2 = contract

      console.log(`abi`, abi)

      const encoded = encodeCreateAccount(abi, 0, 0, w1.address, sig)
    })
  })
})

async function processTransaction(contract: Contract, tx: MsgTransactionDTO) {
  // switch (tx.type.toString()) {
  // case TransactionType.createAccount.toString():
  console.log(tx)
  console.log(tx.createAccount.Account, tx.createAccount.Signature)
  const txn = await contract.createAccount(
    tx.traceID,
    tx.txID,
    tx.createAccount.Account,
    tx.createAccount.Signature,
    txRequestDefault()
  )
  await txn.wait()
  console.log(txn.hash)
  // default:
  // throw new Error("Unknown transaction type")
  // }
}

function encodeCreateAccount(abi: any, timestamp: any, txID: any, accountID: string, sig: Signature): string {
  const enc = new ethers.utils.AbiCoder()
  const encoded = enc.encode(abi, ["createAccount", timestamp, txID, accountID, sig])
  console.log(encoded)
  return ethers.utils.hexlify(encoded)
}

export const getTheAbi = (): ReadonlyArray<string> | null => {
  try {
    // Load the JSON file containing the ABI
    const abiJson = fs.readFileSync("./artifacts-zk/contracts/exchange/GRVTExchange.sol/GRVTExchange.json")
    const abi = JSON.parse(abiJson.toString()).abi as ReadonlyArray<string>
    return abi
  } catch (e) {
    console.error(`Error reading ABI: ${e}`)
    return null
  }
}
