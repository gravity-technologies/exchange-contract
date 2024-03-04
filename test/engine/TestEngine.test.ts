import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../../deploy/utils"
import { getProvider } from "../../deploy/utils"
import { expectToThrowAsync, getDeployerWallet, wallet } from "../util"
import { ExAccountSigners, TestCase, loadTestFilesFromDir, parseTestsFromFile } from "./TestEngineTypes"
import { expectAccountSigners } from "./Getters"
import { expect } from "chai"

const gasLimit = 2100000
const testDir = "/test/engine/testgen/"

// We skip these tests in CI since the era test node cannot run these tests
describe.skip("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  let w1 = getDeployerWallet()
  let testFiles = loadTestFilesFromDir(process.cwd() + testDir)

  before(async () => {
    const deployingWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchangeTest", [], { wallet: deployingWallet, silent: true, noVerify: true })
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  testFiles.forEach((file) => {
    describe(file, async function () {
      let tests = parseTestsFromFile(process.cwd() + testDir + file)
      tests.forEach((test) => {
        it(test.name + ` correctly runs`, async function () {
          await validateTest(test, contract, w1)
        })
      })
    })
  })
})

async function validateTest(test: TestCase, contract: Contract, w1: Wallet) {
  for (const step of test.steps) {
    var tx: ethers.providers.TransactionRequest = {
      to: contract.address,
      gasLimit: gasLimit,
      data: step.tx_data,
    }
    w1 = w1.connect(getProvider())
    const resp = await w1.sendTransaction(tx)
    if (step.ret != "") {
      await expectToThrowAsync(resp.wait())
    } else {
      await resp.wait()
      for (let expectation of step.expectations) {
        let castedExp = expectation as ExAccountSigners
        if (castedExp.address != undefined) {
          await expectAccountSigners(contract, castedExp)
        }
      }
    }
  }
  return
}
