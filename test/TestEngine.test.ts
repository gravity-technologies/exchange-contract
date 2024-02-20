import { expect } from "chai"
import { Contract } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../deploy/utils"
import * as fs from "fs"

import {
  addAccountSigner,
  addWithdrawalAddress,
  createAccount,
  removeAccountSigner,
  removeWithdrawalAddress,
  txRequestDefault,
} from "./api"
import { AccPerm } from "./type"
import { expectToThrowAsync, getDeployerWallet, wallet } from "./util"

interface Expectation {
  NumAccounts: number
  Address: string
  Signers: Record<string, string>
}

interface Step {
  Time: number
  Tx: MsgTransactionDTO
  Ret: any
  Expectations: Expectation[]
}

interface Test {
  Name: string
  Steps: Step[]
}

function parseTestsFromFile(filePath: string): Test[] {
  try {
    // Read the JSON file
    const data = fs.readFileSync(filePath, "utf8")

    // Parse the JSON data into a Test[] array
    const tests: Test[] = JSON.parse(data)

    return tests
  } catch (err) {
    return []
  }
}

describe.only("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  const w1 = wallet()
  const accID = w1.address
  let ts: number
  let tests = parseTestsFromFile(process.cwd() + "/test/tests/CreateAccount.json")

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

  for (const test of tests) {
    describe(test.Name, function () {
      it("should pass", async function () {
        if (test.Steps.length === 0) {
          throw new Error("Test has no steps")
        }
        for (const step of test.Steps) {
          processTransaction(contract, step.Tx)
          checkExpectations(contract, step.Expectations)
        }
      })
    })
  }
})

async function processTransaction(contract: Contract, tx: MsgTransactionDTO) {
  console.log(tx.type.toString())
  console.log(TransactionType.createAccount.toString())
  switch (tx.type.toString()) {
    case TransactionType.createAccount.toString():
      console.log("here it is")
      const txn = await contract.createAccount(
        tx.traceID,
        tx.txID,
        tx.createAccount.Account,
        tx.createAccount.Signature,
        txRequestDefault()
      )
      await txn.wait()
    default:
      throw new Error("Unknown transaction type")
  }
}

async function checkExpectations(contract: Contract, expectations: Expectation[]) {
  for (const e of expectations) {
    const [id, multisigThreshold, subAccounts, adminCount, signerCount]: [string, number, number[], number, number] =
      await contract.getAccount(e.Address)
    console.log("id", id)
    expect(signerCount).to.equal(e.Signers.length)
  }
}
