import { Contract } from "ethers"
import { ethers } from "hardhat"
import { addSubSigner, createSubAcc, removeSubSigner, setSignerPermission, setSubAccountMarginType } from "./api"
import { genRemoveSubAccountSignerPayloadSig, genSetSubAccountSignerPermissionsPayloadSig } from "./signature"
import { MarginType, Perm } from "./type"
import { expectToThrowAsync, nonce, wallet } from "./util"

describe("API - SubAccount", function () {
  let contract: Contract

  beforeEach(async () => {
    contract = await ethers.deployContract("GRVTExchange")
  })

  describe("setSubAccountMarginType", function () {
    it("admin can switch margin type", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      await setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED)
    })

    // TODO
    it("signer with permission can switch margin type", async function () {})
    it("fails if user doesn't have permission", async function () {})
    it("fails if there are open positions", async function () {})
  })

  describe("addSubAccountSigner", function () {
    it("admin can add subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const accID = 1
      let ts = 1
      const subID = wallet().address
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      const signer = wallet()
      ts++
      addSubSigner(contract, ts, ts, admin, subID, signer.address, Perm.Admin)
    })

    it("fails if subaccount doesn't exists", async function () {
      const admin = wallet()
      const subID = wallet().address
      let ts = 1
      expectToThrowAsync(setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED))
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const accID = 1
      let ts = 1
      const subID = wallet().address
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      expectToThrowAsync(setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED))
    })

    it("fails no permission", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without any permission
      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.None)

      // Try to add another subaccount signer from
      const bob = wallet()
      ts++
      expectToThrowAsync(addSubSigner(contract, ts, ts, alice, subID, bob.address, Perm.None))
    })

    it("fails if the signer is already a subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const accID = 1
      let ts = 1
      const subID = wallet().address
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      const signer = wallet().address

      ts++
      await addSubSigner(contract, ts, ts, admin, subID, signer, 1)
      ts++
      expectToThrowAsync(addSubSigner(contract, ts, ts, admin, subID, signer, 1))
    })
  })

  describe("setSubAccountSignerPermissions", function () {
    it("acc-admin/sub-account-admin/signer-with-permission can change permission of subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.UpdateSignerPermission | Perm.Trade)

      ts++
      // Least privilege signer
      const carl = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, carl.address, Perm.Withdrawal)

      // Test
      ts++
      // account admin can change permission of any signer
      await setSignerPermission(contract, admin, ts, ts, subID, carl.address, Perm.Deposit)
      ts++
      // subaccount admin can change permission of any signer
      await setSignerPermission(contract, alice, ts, ts, subID, carl.address, Perm.Admin)
      ts++
      // subaccount signer with update permission can change permission of any signer
      await setSignerPermission(contract, bob, ts, ts, subID, carl.address, Perm.Trade)
    })

    it("fails if signer is account admin", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      expectToThrowAsync(
        setSignerPermission(contract, admin, ts, ts, subID, admin.address, Perm.Trade),
        "signer is acc admin"
      )
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address

      // Test
      let ts = 1
      expectToThrowAsync(setSignerPermission(contract, admin, ts, ts, subID, admin.address, Perm.Trade))
    })

    it("fails if subaccount signer doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // Test
      const alice = wallet()
      ts++
      await expectToThrowAsync(
        setSignerPermission(contract, admin, ts, ts, subID, alice.address, Perm.Trade),
        "signer not found"
      )
    })

    it("fails if new permission is more privileged than current user's permission", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Trade | Perm.UpdateSignerPermission)

      const bob = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.Withdrawal)

      // Test
      ts++
      expectToThrowAsync(
        setSignerPermission(contract, alice, ts, ts, subID, bob.address, Perm.Admin),
        "invalid permission"
      )
      ts++
      expectToThrowAsync(
        setSignerPermission(contract, alice, ts, ts, subID, bob.address, Perm.Deposit),
        "invalid permission"
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
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      // Test
      ts++
      // account admin can change permission of any signer
      const salt = nonce()
      const sig = genSetSubAccountSignerPermissionsPayloadSig(admin, subID, alice.address, Perm.Trade, salt)
      expectToThrowAsync(
        contract.setSubAccountSignerPermissions(ts, ts, subID, alice.address, Perm.Deposit, salt, sig),
        "invalid signature"
      )
    })

    it("fails if current user doesn't have permission to update", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Trade)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.Trade)

      // Test
      ts++
      // account admin can change permission of any signer
      expectToThrowAsync(
        setSignerPermission(contract, alice, ts, ts, subID, bob.address, Perm.Deposit),
        "invalid permission"
      )
    })
  })

  describe("removeSubAccountSigner", function () {
    it("admin can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      // Test
      ts++
      await removeSubSigner(contract, admin, ts, ts, subID, alice.address)
    })

    it("subaccount admin can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.UpdateSignerPermission | Perm.Trade)

      // Test
      ts++
      await removeSubSigner(contract, alice, ts, ts, subID, bob.address)
    })

    it("user with removal permission can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.RemoveSigner)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.Deposit)

      // Test
      ts++
      await removeSubSigner(contract, alice, ts, ts, subID, bob.address)
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      let ts = 1

      // SubAccount admin
      const alice = wallet()

      // Test
      expectToThrowAsync(removeSubSigner(contract, admin, ts, ts, subID, alice.address), "subaccount does not exist")
    })

    it("fails if subaccount signer doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      // SubAccount admin
      const alice = wallet()

      // Test
      ts++
      expectToThrowAsync(removeSubSigner(contract, admin, ts, ts, subID, alice.address), "signer not found")
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      // Test
      ts++
      // account admin can change permission of any signer
      const salt = nonce()
      const sig = genRemoveSubAccountSignerPayloadSig(admin, subID, alice.address, salt)
      expectToThrowAsync(
        contract.removeSubAccountSigner(ts, ts, subID, alice.address, salt + 1, sig),
        "invalid signature"
      )
    })

    it("fails if current user doesn't have permission to remove", async function () {
      // Setup
      const admin = wallet()
      const subID = wallet().address
      const accID = 1
      let ts = 1
      await createSubAcc(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, Perm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, Perm.UpdateSignerPermission | Perm.Trade)

      // Test
      ts++
      expectToThrowAsync(removeSubSigner(contract, bob, ts, ts, subID, alice.address), "no permission")
    })
  })
})
