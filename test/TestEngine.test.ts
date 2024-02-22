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

// A Test is a sequence of test cases
type Test = TestCase[]

interface TestCase {
  // Name of the test case
  Name: string
  // A test case is a sequence of test steps
  Steps: TestStep[]
}

// A test step is a transaction to be executed and the expected result
interface TestStep {
  // The time at which the transaction is executed (if left blank, its value is the same as the previous test step)
  Time: bigint // number is not int64, alternatively use string.

  // The transaction to be executed in this test step
  Tx: MsgTransactionDTO

  // The expected result of running the transaction
  Ret: any // Is there a type more specific than any here?

  // List of expectations to be executed after the transaction is executed
  Expectations: Expectation[]
}

interface Expectation {
  // Replace should/state with TS equivalents
}

function parseTestsFromFile(filePath: string): TestCase[] {
  try {
    // Read the JSON file
    const data = fs.readFileSync(filePath, "utf8")

    // Parse the JSON data into an array of Test objects

    try {
      const tests = JSON.parse(data) as TestCase[]
      return tests
    } catch (error) {
      console.error("Failed to parse JSON:", error)
      return []
    }
  } catch (err) {
    console.log(`Error reading file from disk: ${err}`)
    return []
  }
}

describe("API - TestEngine", function () {
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
          await processTransaction(contract, step.Tx)
          await checkExpectations(contract, step.Expectations)
        }
      })
    })
  }
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

async function checkExpectations(contract: Contract, expectations: Expectation[]) {
  for (const e of expectations) {
    // const [id, multisigThreshold, subAccounts, adminCount, signerCount]: [string, number, number[], number, number] =
    //   await contract.getAccount(e.Address)
    // console.log("id", id)
    // expect(signerCount).to.equal(e.Signers.length)
  }
}
