import { Contract } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../deploy/utils"
import { addSessionKey, removeSessionKey } from "./api"
import { getTimestampNs, wallet } from "./util"

describe("API - Session Key", function () {
  let contract: Contract
  let snapshotId: string

  before(async () => {
    const wallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    contract = await deployContract("GRVTExchange", [], { wallet, silent: true, noVerify: true })
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })
  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  describe("addSessionKey", () => {
    it("should add session key", async () => {
      const signer = wallet()
      let ts = 1
      // Log relevant values for debugging
      await addSessionKey(contract, signer, ts, ts, wallet().address, getTimestampNs(1))
    })
  })

  describe("removeSessionKey", () => {
    it("should remove session key", async () => {
      const signer = wallet()
      let ts = 1
      await addSessionKey(contract, signer, ts, ts, wallet().address, getTimestampNs(1))
      ts++
      await removeSessionKey(contract, signer, ts, ts)
    })

    it("noop if remove non-existent session key", async () => {
      const signer = wallet()
      let ts = 1
      await removeSessionKey(contract, signer, ts, ts)
    })
  })
})
