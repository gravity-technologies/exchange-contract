import { Contract } from "ethers"
import { ethers } from "hardhat"
import {
  addAccAdmin,
  addAccGuardian,
  addSessionKey,
  addSubSigner,
  createSubAcc,
  removeSessionKey,
  setMultisigThreshold,
} from "./api"
import { expectToThrowAsync, getTimestampNs, nonce, wallet } from "./util"
import { Perm } from "./type"
import { genAddSessionKeySig, genRemoveSessionKeySig } from "./signature"

describe("API - Session", function () {
  let contract: Contract

  beforeEach(async () => {
    contract = await ethers.deployContract("GRVTExchange")
  })

  describe("addSessionKey", function () {
    it("admin can add session key", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      const expiry = getTimestampNs(10)
      await addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry)
    })

    it("subaccount signer with Trade permission can add session", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without Trade permission
      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Trade)

      ts++
      const expiry = getTimestampNs(10)
      await addSessionKey(contract, alice, ts, ts, subID, wallet().address, expiry)
    })

    it("can override existing session key", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add 1 session key
      ts++
      const expiry = getTimestampNs(10)
      await addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry)

      // Add another session key
      ts++
      await addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry)
    })

    it("fails if expiry is in the past", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add 1 session key
      ts++
      const expiry = getTimestampNs(-1)
      expectToThrowAsync(addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry), "invalid expiry")
    })

    it("fails if subaccount does not exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      let ts = 1

      // Add 1 session key
      const expiry = getTimestampNs(10)
      expectToThrowAsync(
        addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry),
        "subaccount does not exist"
      )
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      const expiry = getTimestampNs(10)
      const salt = nonce()
      const sig = genAddSessionKeySig(admin, subID, wallet().address, expiry, salt)
      expectToThrowAsync(
        contract.addSessionKey(ts, ts, subID, wallet().address, expiry, salt, sig),
        "invalid signature"
      )
    })

    it("fails if signer is not an admin or a subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without Trade permission
      const alice = wallet()

      ts++
      const expiry = getTimestampNs(10)
      expectToThrowAsync(addSessionKey(contract, alice, ts, ts, subID, wallet().address, expiry), "no permission")
    })

    it("fails if signer is a subaccount signer but no trade permission", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without Trade permission
      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Withdrawal)

      ts++
      const expiry = getTimestampNs(10)
      expectToThrowAsync(addSessionKey(contract, alice, ts, ts, subID, wallet().address, expiry), "no permission")
    })
  })

  describe("removeSessionKey", function () {
    it("can remove session key successfully", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      const expiry = getTimestampNs(10)
      await addSessionKey(contract, admin, ts, ts, subID, wallet().address, expiry)

      ts++
      await removeSessionKey(contract, admin, ts, ts, subID)
    })

    it("no-op if there is no existing session", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      await removeSessionKey(contract, admin, ts, ts, subID)
    })

    it("fails if subaccount does not exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      let ts = 1

      expectToThrowAsync(removeSessionKey(contract, admin, ts, ts, subID), "subaccount does not exist")
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      const salt = nonce()
      const sig = genRemoveSessionKeySig(admin, subID, salt)
      expectToThrowAsync(contract.addSessionKey(ts, ts, subID, salt, sig), "invalid signature")
    })

    it("fails if signer is not an admin or a subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without Trade permission
      const alice = wallet()

      ts++
      expectToThrowAsync(removeSessionKey(contract, alice, ts, ts, subID), "no permission")
    })

    it("fails if signer is a subaccount signer but no trade permission", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without Trade permission
      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Withdrawal)

      ts++
      const expiry = getTimestampNs(10)
      expectToThrowAsync(removeSessionKey(contract, alice, ts, ts, subID), "no permission")
    })
  })
})
