import { Contract, ethers } from "ethers"
import { network } from "hardhat"
import { Wallet } from "zksync-ethers"
import { LOCAL_RICH_WALLETS, deployContract, getProvider, getWallet } from "../../deploy/utils"
import { expectToThrowAsync, getDeployerWallet } from "../util"
import { validateExpectations } from "./Getters"
import { TestCase, loadTestFilesFromDir, parseTestsFromFile } from "./TestEngineTypes"

const gasLimit = 2100000000
const testDir = "/test/engine/testfixtures/"

// We skip these tests in CI since the era test node cannot run these tests
describe.only("API - TestEngine", function () {
  let contract: Contract
  let snapshotId: string
  let w1 = getDeployerWallet()
  let testFiles = loadTestFilesFromDir(process.cwd() + testDir)

  before(async () => {
    const deployingWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchangeTest", [], { wallet: deployingWallet, silent: true, noVerify: true })
    await contract.initialize()
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  const filters: string[] = [
    "TestAccountMultisig.json",
    "TestAccountSigners.json",
    "TestConfigChain.json",
    "TestConfigChainDefault.json",
    "TestCreateAccount.json",
    "TestFundingRate.json",
    "TestInterestRate.json",
    "TestMarkPrice.json",
    "TestMatchFeeComputation.json",
    "TestMatchFundingAndSettlement.json",
    "TestMatchTradingComputation.json",
    "TestRecoverWallet.json",
    "TestSessionKey.json",
    "TestSettlementPrice.json",
    "TestSubAccount.json",
    "TestDeposit.json",
    "TestTransfer.json",
    "TestWithdrawal.json",
  ]
  const testNames: string[] = [
    // "[NoFee, NoMargin] One Leg One Maker (Simple Buy and Close)",
    // "[NoFee, NoMargin] One Leg One Maker (Simple Buy and Close)"
  ]
  testFiles
    .filter((t) => filters.includes(t))
    .forEach((file) => {
      describe(file, async function () {
        let tests = parseTestsFromFile(process.cwd() + testDir + file)
        tests = tests.filter((t) => testNames.length == 0 || testNames.includes(t.name))
        tests.slice().forEach((test) => {
          it(test.name + ` correctly runs`, async function () {
            await validateTest(test, contract, w1)
          })
        })
      })
    })
})

async function validateTest(test: TestCase, contract: Contract, w1: Wallet) {
  const steps = test.steps ?? []
  for (const step of steps) {
    if (step.tx_data == "") {
      await validateExpectations(contract, step.expectations)
      continue
    }

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
      // console.log("Step", (step as any).tx.tx_id)
      await resp.wait()
      await validateExpectations(contract, step.expectations)
    }
  }

  return
}