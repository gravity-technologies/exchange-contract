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
} from "./api"
import { AccPerm } from "./type"
import { expectToThrowAsync, getDeployerWallet, wallet } from "./util"

interface Step {
  Time: number
  Tx: MsgTransactionDTO
  Ret: any
  Expectations: any
}

interface Test {
  name: string
  steps: Step[]
}

function parseTestsFromFile(filePath: string): Test[] {
  try {
    // Read the JSON file
    const data = fs.readFileSync(filePath, "utf8")

    // Parse the JSON data into a Test[] array
    const tests: Test[] = JSON.parse(data)

    return tests
  } catch (err) {
    console.error("Error parsing JSON file:", err)
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
    describe("setAccountMultiSigThreshold", function () {
      it("should pass", async function () {})
    })
  }
})
