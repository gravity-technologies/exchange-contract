import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../../deploy/utils"
import { getProvider } from "../../deploy/utils"
import { expectToThrowAsync, getDeployerWallet, wallet } from "../util"
import { TestCase, loadTestFilesFromDir, parseTestsFromFile } from "./testEngineTypes"

// We skip these tests in CI since the era test node cannot run these tests
describe.skip("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  var w1 = getDeployerWallet()
  var files = loadTestFilesFromDir(process.cwd() + "/test/engine/testgen/")

  before(async () => {
    const deployingWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchange", [], { wallet: deployingWallet, silent: true, noVerify: true })
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  let testSuite = files
  testSuite.forEach((file) => {
    describe(file, async function () {
      let tests = parseTestsFromFile(process.cwd() + "/test/engine/testgen/" + file)
      tests.forEach((test) => {
        it(test.name + ` correctly runs`, async function () {
          await validateTest(test, contract, w1)
        })
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
