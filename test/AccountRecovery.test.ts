import { expect } from "chai"
import { Contract } from "ethers"
import { LOCAL_RICH_WALLETS, deployContract, deployContractUpgradable, getWallet } from "../deploy/utils"
import {
  MAX_GAS,
  addAccountGuardian,
  addAccountSigner,
  createAccount,
  createSubAccount,
  recoverAccountAdmin,
  removeAccountGuardian,
  setMultisigThreshold,
} from "./api"
import { genAddAccountGuardianPayloadSig, genRemoveAccountGuardianPayloadSig } from "./signature"
import { AccPerm, AccountRecoveryType, ConfigID } from "./type"
import { Bytes32, bytes32, getConfigArray, nonce, wallet } from "./util"

describe("API - AccountRecovery", function () {
  let contract: Contract
  const grvt = wallet()

  beforeEach(async () => {
    const wallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    const recoveryAddress = await bytes32(grvt)
    const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, recoveryAddress]]))
    // contract = await deployContract("GRVTExchange", [config], { wallet, silent: true })
    contract = await deployContractUpgradable("GRVTExchange", [config], { wallet, silent: true })
  })

  describe("addAccountGuardian", function () {
    it("can add guardian successfully", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian = wallet().address
      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).not.to.be.reverted

      // Test: 2 admins
      const guardian2 = wallet().address
      const alice = wallet()
      ts++
      await expect(addAccountSigner(contract, [admin], ts, ts, accID, alice.address, AccPerm.Admin)).not.to.be.reverted

      // Update quorum to 2
      ts++
      await expect(setMultisigThreshold(contract, [admin], ts, ts, accID, 2)).not.to.be.reverted

      ts++
      await expect(addAccountGuardian(contract, [admin, alice], ts, ts, accID, guardian2)).not.to.be.reverted
    })

    it.skip("fails if signer is not an admin", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const guardian = wallet().address
      ts++
      await expect(addAccountGuardian(contract, [wallet()], ts, ts, accID, guardian)).to.be.reverted
      // TODO "ineligible signer"
    })

    it("fails if account does not exist", async function () {
      const accID = wallet().address
      let ts = 1

      // Test
      const guardian = wallet().address
      await expect(addAccountGuardian(contract, [wallet()], ts, ts, accID, guardian)).to.be.reverted
      // TODO "account does not exist"
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian = wallet().address
      ts++
      const salt = nonce()
      const sig = genAddAccountGuardianPayloadSig(admin, accID, guardian, salt + 1)
      await expect(contract.addAccountGuardian(ts, ts, accID, guardian, salt, [sig], { gasLimit: MAX_GAS })).to.be
        .reverted
      // TODO "invalid signature"
    })

    it.skip("fails if quorum is not met", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const guardian = wallet().address
      const alice = wallet()
      ts++
      await expect(addAccountSigner(contract, [admin], ts, ts, accID, alice.address, AccPerm.Admin)).not.to.be.reverted

      // Update quorum to 2
      ts++
      await expect(setMultisigThreshold(contract, [admin], ts, ts, accID, 2)).not.to.be.reverted

      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).to.be.reverted
      // TODO "failed quorum"
    })

    it("fails if guardian already exists", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian = wallet().address
      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).not.to.be.reverted
      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).to.be.reverted
      // TODO "address exists"
    })
  })

  describe("removeAccountGuardian", function () {
    it("admin can remove guardian successfully, quorum=1", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian = wallet().address
      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).not.to.be.reverted

      ts++
      await expect(removeAccountGuardian(contract, [admin], ts, ts, accID, guardian)).not.to.be.reverted
    })

    it("admin can remove guardian successfully, quorum=2", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const guardian = wallet().address
      ts++
      await expect(addAccountGuardian(contract, [admin], ts, ts, accID, guardian)).not.to.be.reverted

      const alice = wallet()
      ts++
      await expect(addAccountSigner(contract, [admin], ts, ts, accID, alice.address, AccPerm.Admin)).not.to.be.reverted

      // Update quorum to 2
      ts++
      await expect(setMultisigThreshold(contract, [admin], ts, ts, accID, 2)).not.to.be.reverted

      ts++
      await expect(removeAccountGuardian(contract, [admin, alice], ts, ts, accID, guardian)).not.to.be.reverted
    })

    it("fails if signer is not an admin", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const guardian = wallet().address
      ts++
      await expect(removeAccountGuardian(contract, [wallet()], ts, ts, accID, guardian)).to.be.reverted
      // TODO "ineligible signer"
    })

    it("fails if account does not exist", async function () {
      const accID = wallet().address
      let ts = 1

      // Test
      const guardian = wallet().address
      await expect(removeAccountGuardian(contract, [wallet()], ts, ts, accID, guardian)).to.be.reverted
      // TODO: "account does not exist"
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian = wallet().address
      ts++
      const salt = nonce()
      const sig = genRemoveAccountGuardianPayloadSig(admin, accID, guardian, salt + 1)
      await expect(contract.removeAccountGuardian(ts, ts, accID, guardian, salt, [sig], { gasLimit: MAX_GAS })).to.be
        .reverted
      // TODO "invalid signature"
    })

    it("fails if quorum is not met", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const guardian = wallet().address
      const alice = wallet()
      ts++
      await expect(addAccountSigner(contract, [admin], ts, ts, accID, alice.address, AccPerm.Admin)).not.to.be.reverted

      // Update quorum to 2
      ts++
      await expect(setMultisigThreshold(contract, [admin], ts, ts, accID, 2)).not.to.be.reverted

      ts++
      await expect(removeAccountGuardian(contract, [admin], ts, ts, accID, guardian)).to.be.reverted
      // TODO "failed quorum"
    })

    it("fails if guardian does not exists", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test: 1 admin
      const guardian2 = wallet().address
      ts++
      await expect(removeAccountGuardian(contract, [admin], ts, ts, accID, guardian2)).to.be.reverted
      // TODO "not found"
    })
  })

  describe("recoverAccountAdmin", function () {
    //   it("can recover using guardian accounts", async function () {
    //     // Setup
    //     const oldAdmin = wallet()
    //     const newAdmin = wallet()
    //     const accID = wallet().address
    //     const subID = 1
    //     let ts = 1
    //     await createSubAccount(contract, oldAdmin, ts, ts, accID, subID)
    //     // Add guardian
    //     const guardian = wallet()
    //     ts++
    //     await addAccountGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)
    //     ts++
    //     await recoverAccountAdmin(
    //       contract,
    //       [guardian],
    //       ts,
    //       ts,
    //       accID,
    //       AccountRecoveryType.GUARDIAN,
    //       oldAdmin.address,
    //       newAdmin.address
    //     )
    //   })
    //   it("can recover using subaccount signers", async function () {
    //     // Setup
    //     const oldAdmin = wallet()
    //     const newAdmin = wallet()
    //     const accID = wallet().address
    //     const subID = 1
    //     let ts = 1
    //     await createSubAccount(contract, oldAdmin, ts, ts, accID, subID)
    //     // Add signer
    //     const signer = wallet()
    //     ts++
    //     addSubSigner(contract, ts, ts, oldAdmin, subID, signer.address, 1)
    //     ts++
    //     await recoverAccountAdmin(
    //       contract,
    //       [signer],
    //       ts,
    //       ts,
    //       accID,
    //       AccountRecoveryType.SUB_ACCOUNT_SIGNERS,
    //       oldAdmin.address,
    //       newAdmin.address
    //     )
    //   })
    //   it("fails if invalid signature", async function () {
    //     // Setup
    //     const oldAdmin = wallet()
    //     const newAdmin = wallet()
    //     const accID = wallet().address
    //     const subID = 1
    //     let ts = 1
    //     await createSubAccount(contract, oldAdmin, ts, ts, accID, subID)
    //     // Add guardian
    //     const guardian = wallet()
    //     ts++
    //     await addAccountGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)
    //     ts++
    //     const salt = nonce()
    //     const sigs = [
    //       genRecoverAccountAdminPayloadSig(
    //         guardian,
    //         accID,
    //         AccountRecoveryType.GUARDIAN,
    //         oldAdmin.address,
    //         newAdmin.address,
    //         salt
    //       ),
    //     ]
    //     await expectToThrowAsync(
    //       contract.recoverAccountAdmin(
    //         ts,
    //         ts,
    //         accID,
    //         AccountRecoveryType.GUARDIAN,
    //         oldAdmin.address,
    //         newAdmin.address,
    //         salt + 2,
    //         sigs
    //       ),
    //       "invalid signature"
    //     )
    //   })
    it("fails if account does not exist", async function () {
      // Setup
      const accID = wallet().address
      const oldAdmin = wallet()
      const newAdmin = wallet()

      let ts = 1
      // await expect(createAccount(contract, oldAdmin, ts, ts, accID)).not.to.be.reverted

      await expect(
        recoverAccountAdmin(
          contract,
          [wallet()],
          ts,
          ts,
          accID,
          AccountRecoveryType.GUARDIAN,
          oldAdmin.address,
          newAdmin.address
        )
      ).to.be.reverted
      // TODO "account does not exist"
    })
    //   it("fails if quorum is not met", async function () {
    //     // Setup
    //     const oldAdmin = wallet()
    //     const newAdmin = wallet()
    //     const accID = wallet().address
    //     const subID = 1
    //     let ts = 1
    //     await createSubAccount(contract, oldAdmin, ts, ts, accID, subID)
    //     // Add 2 guardians, quorum should be 2 votes to be able to recover
    //     const guardian = wallet()
    //     const guardian2 = wallet()
    //     ts++
    //     await addAccountGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)
    //     ts++
    //     await addAccountGuardian(contract, [oldAdmin], ts, ts, accID, guardian2.address)
    //     ts++
    //     await expectToThrowAsync(
    //       recoverAccountAdmin(
    //         contract,
    //         [guardian],
    //         ts,
    //         ts,
    //         accID,
    //         AccountRecoveryType.GUARDIAN,
    //         oldAdmin.address,
    //         newAdmin.address
    //       ),
    //       "failed quorum"
    //     )
    //   })
    //   it("fails if signer is not guardian or subaccount signer", async function () {
    //     // Setup
    //     const oldAdmin = wallet()
    //     const newAdmin = wallet()
    //     const accID = wallet().address
    //     const subID = 1
    //     let ts = 1
    //     await createSubAccount(contract, oldAdmin, ts, ts, accID, subID)
    //     // Test
    //     const guardian = wallet()
    //     ts++
    //     await addAccountGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)
    //     ts++
    //     await expectToThrowAsync(
    //       recoverAccountAdmin(
    //         contract,
    //         [wallet()],
    //         ts,
    //         ts,
    //         accID,
    //         AccountRecoveryType.GUARDIAN,
    //         oldAdmin.address,
    //         newAdmin.address
    //       ),
    //       "ineligible signer"
    //     )
    //   })
  })
})
