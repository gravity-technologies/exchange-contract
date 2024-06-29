import { expect } from "chai"
import { Contract, ethers } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract } from "../deploy/utils"
import { createAccount } from "./api"
import { expectToThrowAsync, getDeployerWallet, wallet } from "./util"

describe("API - AccessControlTest", function () {
  let contract: Contract
  let snapshotId: string

  before(async () => {
    const wallet = getDeployerWallet()
    contract = await deployContract("GRVTExchange", [], { wallet, silent: true, noVerify: true })
    await contract.initialize()
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })
  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  describe("txSender", function () {
    it("when correct, should be able to send txn", async function () {
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      contract.connect(getDeployerWallet())
      await createAccount(contract, admin, ts, ts, accID)
    })

    it("when incorrect, should not be able to send txn", async function () {
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      let incorrectSigner = wallet()
      contract = contract.connect(incorrectSigner)
      let tx = createAccount(contract, admin, ts, ts, accID)
      await expectToThrowAsync(tx)
      ts++
    })
  })
})
