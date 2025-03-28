import { Contract, ethers } from "ethers"
import { network } from "hardhat"
import { Wallet } from "zksync-ethers"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { TestCase } from "./types"
import { setupTestEnvironment } from "./setup"
import { runTestCase } from "./runner"
import { getTestFixtures, parseTestsFromFile } from "./util"

const TEST_FIXTURES_DIR = process.cwd() + "/test/engine/fixtures/"

describe("API - TestEngine", function () {
  let exchangeContract: Contract
  let l2SharedBridgeAsL1Bridge: Contract
  let runSnapshotId: string
  let testSnapshotId: string
  let w1: Wallet
  before(async () => {
    ({ exchangeContract, l2SharedBridgeAsL1Bridge, w1 } = await setupTestEnvironment())
    runSnapshotId = await network.provider.send("evm_snapshot")
  })

  after(async () => {
    await network.provider.send("evm_revert", [runSnapshotId])
  })

  beforeEach(async () => {
    testSnapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [testSnapshotId])
  })

  const testFiles = getTestFixtures(TEST_FIXTURES_DIR)
  const testNamesFilter: string[] = []

  testFiles.forEach((file) => {
    describe(file, function () {
      const tests = parseTestsFromFile(`${TEST_FIXTURES_DIR}/${file}`).filter(
        (t) => testNamesFilter.length === 0 || testNamesFilter.includes(t.name)
      )

      tests.forEach((test: TestCase) => {
        it(test.name, async function () {
          await runTestCase(test, exchangeContract, w1, l2SharedBridgeAsL1Bridge)
        })
      })
    })
  })
})
