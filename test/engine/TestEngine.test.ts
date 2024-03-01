import { expect } from "chai"
import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../../deploy/utils"
import * as fs from "fs"
import { getProvider } from "../../deploy/utils"
import { expectToThrowAsync, getDeployerWallet, wallet } from "../util"

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

  // The function abi encoded transaction to be executed
  tx_data: string

  // The expected result of running the transaction
  ret: string

  // List of expectations to be executed after the transaction is executed
  expectations: Expectation[]
}

interface Expectation {
  // Add should states here
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

function loadTestFilesFromDir(dir: string): string[] {
  return fs.readdirSync(dir).map((file) => `${file}`)
}

// We skip these tests in CI since the era test node cannot run these tests
describe.only("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  var w1 = getDeployerWallet()
  var files = loadTestFilesFromDir(process.cwd() + "/test/engine/testgen/")
  console.log(files)

  before(async () => {
    const deployingWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchange", [], { wallet: deployingWallet, silent: true, noVerify: true })
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  describe("add()", function () {
    let tests = parseTestsFromFile(process.cwd() + "/test/engine/testgen/TestCreateAccount.json")
    tests.forEach((test) => {
      it(`correctly runs ` + test.name, async function () {
        await validateTest(test, contract, w1)
      })
    })
  })
})

async function validateTest(test: TestCase, contract: Contract, w1: Wallet) {
  if (test.steps.length === 0) {
    throw new Error("Test has no steps")
  }
  for (const step of test.steps) {
    var tx: ethers.providers.TransactionRequest = {
      to: contract.address,
      gasLimit: 2100000,
      data: step.tx_data,
    }
    w1 = w1.connect(getProvider())
    const resp = await w1.sendTransaction(tx)
    if (step.ret != "") {
      await expectToThrowAsync(resp.wait())
    } else {
      await resp.wait()
    }
  }
  return
}
