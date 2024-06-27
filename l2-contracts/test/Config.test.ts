import { Contract } from "ethers"
import { network } from "hardhat"
import { deployContract } from "../deploy/utils"
import { getDeployerWallet, wallet } from "./util"

describe("API - Config", function () {
  let contract: Contract
  let snapshotId: string
  const grvt = wallet()

  before(async () => {
    const wallet = getDeployerWallet()
    contract = await deployContract("GRVTExchange", [], { wallet, silent: true, noVerify: true })
    // contract = await deployContractUpgradable("GRVTExchange", [], { wallet, silent: true })
  })
  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  // describe("scheduleConfig", function () {
  //   it("can schedule config successfully", async function () {
  //     let ts = 1
  //     const call = scheduleConfig(contract, grvt, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt))
  //     await expect(call).to.not.be.reverted

  //     // ts++
  //     // TODO: add event assertion. For now there's a problem with setting up the dependencies
  //     // await expect(
  //     // scheduleConfig(contract, grvt, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt.address))
  //     // ).to.emit(contract, "ConfigScheduledEvent")
  //     // .withArgs(ConfigID.ADMIN_RECOVERY_ADDRESS, anyValue)
  //   })

  //   it("fails if signer is not authorized to schedule config change", async function () {
  //     let ts = 1
  //     const w = wallet()
  //     await expectToThrowAsync(
  //       scheduleConfig(contract, w, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(w)),
  //       "unauthorized"
  //     )
  //   })

  //   it("fails if invalid signature", async function () {
  //     let ts = 1
  //     const salt = nonce()
  //     const sig = genScheduleConfigSig(grvt, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt), salt)
  //     await expectToThrowAsync(
  //       contract.scheduleConfig(ts, ts, ConfigID.PM_EXTREME_MOVE_DISCOUNT, bytes32(grvt), salt, sig),
  //       "invalid signature"
  //     )
  //   })
  // })

  describe("setConfig", function () {
    // it("set address config successfully", async function () {
    //   const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
    //   const contract = await ethers.deployContract("GRVTExchange", [config])
    //   const newWallet = wallet()
    //   // schedule
    //   let ts = 1
    //   await scheduleConfig(contract, grvt, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(newWallet))
    //   // Update
    //   ts++
    //   await setConfig(contract, grvt, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(newWallet))
    // })
    // it("can set uint config successfully after a schedule", async function () {
    //   const config = getConfigArray(
    //     new Map<number, Bytes32>([
    //       [ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)],
    //       [ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100)],
    //     ])
    //   )
    //   const contract = await ethers.deployContract("GRVTExchange", [config])
    //   // schedule
    //   let ts = 1
    //   await scheduleConfig(contract, grvt, ts, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(109))
    //   // Update
    //   ts++
    //   await setConfig(contract, grvt, 900000, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(109))
    // })
    // it("can set uint config successfully from initially 0 value", async function () {
    //   const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
    //   const contract = await ethers.deployContract("GRVTExchange", [config])
    //   // schedule
    //   let ts = 1
    //   await scheduleConfig(contract, grvt, ts, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100))
    //   // Update
    //   ts++
    //   await setConfig(contract, grvt, 90000, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100))
    // })
    // it("set uint: delta is too large, applied the last rule timelock", async function () {})
    // No int config yet
    // it("can set int config successfully, positive delta", async function () {})
    // it("can set int config successfully, negative delta", async function () {})
    // it("can set int config successfully from initially 0 value", async function () {})
    // it("fails if config is still locked", async function () {
    //   const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
    //   const contract = await ethers.deployContract("GRVTExchange", [config])
    //   // schedule
    //   let ts = 1
    //   await scheduleConfig(contract, grvt, ts, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100))
    //   // Update,
    //   ts++
    //   // Fails: timestamp < than the timelock duration (1 day)
    //   await expectToThrowAsync(
    //     setConfig(contract, grvt, ts, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100)),
    //     "config is locked"
    //   )
    //   // Success: timestamp > than the timelock duration (1 day)
    //   await setConfig(contract, grvt, 90000, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100))
    // })
    // it("fails if value was not scheduled", async function () {
    //   const config = getConfigArray(
    //     new Map<number, string>([
    //       [ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)],
    //       [ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(100)],
    //     ])
    //   )
    //   const contract = await ethers.deployContract("GRVTExchange", [config])
    //   let ts = 1
    //   await expectToThrowAsync(
    //     setConfig(contract, grvt, 9000000, ts, ConfigID.SM_FUTURES_INITIAL_MARGIN, bytes32(109)),
    //     "not scheduled"
    //   )
    // })
    // it("fails if invalid signature", async function () {
    //   let ts = 1
    //   const salt = nonce()
    //   const sig = genSetConfigSig(grvt, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt), salt)
    //   await expectToThrowAsync(
    //     contract.setConfig(ts, ts, ConfigID.PM_EXTREME_MOVE_DISCOUNT, bytes32(grvt), salt, sig),
    //     "invalid signature"
    //   )
    // })
    // it("fails if signer is not authorized to set config change", async function () {
    //   // Update
    //   let ts = 1
    //   const w = wallet()
    //   await expectToThrowAsync(
    //     setConfig(contract, w, ts, ts, ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(w)),
    //     "unauthorized"
    //   )
    // })
  })
})
