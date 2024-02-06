import { expect } from "chai"
import { Contract } from "ethers"
import { network } from "hardhat"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../deploy/utils"
import {
  addAccountSigner,
  addWithdrawalAddress,
  createAccount,
  removeAccountSigner,
  removeWithdrawalAddress,
  setMultisigThreshold,
} from "./api"
import { AccPerm } from "./type"
import { expectToThrowAsync, wallet } from "./util"

// Acount

// Signners
// Add Acc Signer
// Remove Acc Signer
// Set Acc Signer Permissions

// Withdrawal Address
// Add Withdrawal Address
// Remove Withdrawal Address

// Transfer
// External Transfer

describe.only("API - Multisig", function () {
  let contract: Contract
  let snapshotId: string
  const w1 = wallet()
  const w2 = wallet()
  const w3 = wallet()
  const accID = w1.address
  let ts: number

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
  describe("setAccountMultiSigThreshold", function () {
    it("Should increase multisig threshold successfully", async function () {
      const w1 = wallet()
      const w2 = wallet()

      const accID = w1.address
      let ts = 1
      await createAccount(contract, w1, ts, ts, accID)

      ts++
      await addAccountSigner(contract, [w1], ts, ts, accID, w2.address, AccPerm.Admin)
      ts++
      await setMultisigThreshold(contract, [w1], ts, ts, accID, 2)
    })

    it("fails if threshold = 0", async function () {
      const w1 = wallet()
      const accID = w1.address

      // 1. Create sub account
      let ts = 1
      await createAccount(contract, w1, ts, ts, accID)

      // 2. Set multisig threshold
      ts++
      const tx = setMultisigThreshold(contract, [w1], ts, ts, accID, 0)
      await expectToThrowAsync(tx)
      //  "invalid threshold"
    })

    it("fails if threshold > number of admins", async function () {
      const w1 = wallet()
      const accID = w1.address
      let ts = 1
      // 1. Create sub account
      await createAccount(contract, w1, ts, ts, accID)
      ts++
      const tx = setMultisigThreshold(contract, [w1], ts, ts, accID, 2)
      await expectToThrowAsync(tx)
      //  "invalid threshold"
    })
  })

  describe("multisig operations  based on set multisig threshold", function () {
    describe("addWithdrawalAddress", function () {
      it("should add withdrawal address if threshold is met", async function () {
        ts = 1
        await createAccount(contract, w1, ts, ts, accID)
        ts++
        await addAccountSigner(contract, [w1], ts, ts, accID, w2.address, AccPerm.Admin)
        ts++
        await setMultisigThreshold(contract, [w1], ts, ts, accID, 2)
        ts++
        const withdrawalAddress = wallet().address
        await addWithdrawalAddress(contract, [w1, w2], ts, ts, accID, withdrawalAddress)
      })

      it("fails if threshold is not met", async function () {
        ts = 1
        await createAccount(contract, w1, ts, ts, accID)
        ts++
        await addAccountSigner(contract, [w1], ts, ts, accID, w2.address, AccPerm.Admin)
        ts++
        await setMultisigThreshold(contract, [w1], ts, ts, accID, 2)
        const withdrawalAddress = wallet().address
        await expectToThrowAsync(addWithdrawalAddress(contract, [w1, w2], ts, ts, accID, withdrawalAddress))
      })
    })

    describe("addAccountSigner and remove account signer", function () {
      it("adding signer needs to meet multisig threshold", async function () {
        ts = 1
        await createAccount(contract, w1, ts, ts, accID)
        ts++
        await addAccountSigner(contract, [w1], ts, ts, accID, w2.address, AccPerm.Admin)
        ts++
        await setMultisigThreshold(contract, [w1], ts, ts, accID, 2)
        ts++
        await addAccountSigner(contract, [w1, w2], ts, ts, accID, w3.address, AccPerm.Admin)
        ts++
        await setMultisigThreshold(contract, [w3, w2], ts, ts, accID, 3)
      })
    })
  })
})
