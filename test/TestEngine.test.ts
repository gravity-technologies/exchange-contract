import { expect } from "chai"
import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../deploy/utils"
import * as fs from "fs"
import { getProvider } from "../deploy/utils"
import { expectToThrowAsync, getDeployerWallet, wallet } from "./util"

// A Test is a sequence of test cases
type Test = TestCase[]

interface TestCase {
  // Name of the test case
  name: string
  // A test case is a sequence of test steps
  steps: TestStep[]
}

// A test step is a transaction to be executed and the expected result
interface TestStep {
  // The time at which the transaction is executed (if left blank, its value is the same as the previous test step)
  time: bigint // number is not int64, alternatively use string.

  // The function abi encoded transaction to be executed
  tx_data: string

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

describe.only("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  var w1 = getDeployerWallet()
  const accID = w1.address
  let ts: number
  let tests = parseTestsFromFile(process.cwd() + "/test/tests/CreateAccount.json")
  console.log("tests:", tests.length)

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

  // for (var test of tests) {
  var test = tests[0]
  // const txData2 =
  //   "0x86db00e10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc04900000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc0493054d5cc36c9fb2e39677d6f7cd60f3a56f4a90dc1d0c8f1adc80b23028e5cde43f3c4b5e127bb8cb6cb1148ce6a274ebbd8515d7d36ad2af29fa2619a3859df000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000017ba7087c4f7e20000000000000000000000000000000000000000000000000000000000003707bc"
  // test.steps[0].tx_data = txData2
  describe(test.name, function () {
    it("should pass", async function () {
      if (test.steps.length === 0) {
        throw new Error("Test has no steps")
      }
      for (const step of test.steps) {
        console.log("🚨", step.tx_data)
        var tx: ethers.providers.TransactionRequest = {
          to: contract.address,
          gasLimit: 2100000,
          data: step.tx_data,
        }
        w1 = w1.connect(getProvider())
        const resp = await w1.sendTransaction(tx)
        await resp.wait()
      }
    })
  })
  // }
})
