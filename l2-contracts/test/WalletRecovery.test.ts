import { Contract } from "ethers"
import { network } from "hardhat"
import { deployContract } from "../deploy/utils"
import { addRecoveryAddress, createAccount, recoverAddress, removeRecoveryAddress } from "./api"
import { getDeployerWallet, wallet } from "./util"

describe("API - Wallet Recovery", function () {
  let contract: Contract
  let snapshotId: string
  const w1 = wallet()
  const w2 = wallet()
  const w3 = wallet()
  const accID = w1.address
  let ts: number

  before(async () => {
    const wallet = getDeployerWallet()
    contract = await deployContract("GRVTExchange", [], { wallet, silent: true, noVerify: true })
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })
  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
    ts = 1
    await createAccount(contract, w1, ts, ts, accID)
    ts++
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  it("should add recovery wallet", async () => {
    await addRecoveryAddress(contract, w1, ts, ts, accID, w1.address, w2.address)
  })

  it("should remove recovery wallet", async () => {
    await addRecoveryAddress(contract, w1, ts, ts, accID, w1.address, w2.address)
    ts++
    await removeRecoveryAddress(contract, w1, ts, ts, accID, w1.address, w2.address)
  })

  it("should recover wallet", async () => {
    await addRecoveryAddress(contract, w1, ts, ts, accID, w1.address, w2.address)
    ts++
    await recoverAddress(contract, w2, ts, ts, accID, w1.address, w2.address, w3.address)
  })
})
