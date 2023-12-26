import { ethers } from "ethers"
import { GRVTExchange } from "../typechain-types"
import {
  addSubSigner,
  createAccount,
  createSubAccount,
  removeSubSigner,
  setSubAccountSignerPermission,
  setSubAccountMarginType,
  MAX_GAS,
} from "./api"
import {
  genRemoveSubAccountSignerPayloadSig,
  genSetSubAccountMarginTypePayloadSig,
  genSetSubAccountSignerPermissionsPayloadSig,
} from "./signature"
import { ConfigID, MarginType, AccPerm, SubPerm } from "./type"
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from "../deploy/utils"
import { Bytes32, bytes32, expectToThrowAsync, getConfigArray, nonce, wallet } from "./util"
import { expect } from "chai"

describe("API - SubAccount", function () {
  let contract: GRVTExchange
  const grvt = wallet()

  beforeEach(async () => {
    const wallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
    const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
    contract = <GRVTExchange>await deployContract("GRVTExchange", [config], { wallet, silent: true })
  })

  describe("createSubAccount", function () {
    it("Should create subaccount successfully", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      const subID = 1
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted
    })

    it("Error if account doesn't exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      const subID = 1
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).to.be.reverted
    })

    it("Error if subaccount already exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      const tx = createAccount(contract, admin, ts, ts, accID)
      await expect(tx).not.to.be.reverted

      ts++
      const subID = 1
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).to.be.reverted
    })
  })

  describe("setSubAccountMarginType", function () {
    it("admin can switch margin type", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      ts++
      await expect(setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED)).not.to.be.reverted
    })

    it("signer with permission can switch margin type", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1
      const alice = wallet()

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.ChangeMarginType)).not.to.be
        .reverted

      // Test
      ts++
      await expect(setSubAccountMarginType(contract, alice, ts, ts, subID, MarginType.ISOLATED)).not.to.be.reverted
    })

    it("fails if user doesn't have permission", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1
      const alice = wallet()

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      ts++
      await expect(setSubAccountMarginType(contract, alice, ts, ts, subID, MarginType.ISOLATED)).to.be.reverted
    })

    // TODO
    it("fails if there are open positions", async function () {})
  })

  describe("addSubAccountSigner", function () {
    it("admin can add subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      const subID = 1
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Test
      const signer = wallet()
      ts++
      await expect(addSubSigner(contract, ts, ts, admin, subID, signer.address, SubPerm.Trade)).not.to.be.reverted
    })

    it("fails if subaccount doesn't exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      const subID = 1
      await expect(setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED)).to.be.reverted
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      const salt = nonce()
      const sig = genSetSubAccountMarginTypePayloadSig(admin, subID, MarginType.ISOLATED, salt)
      await expect(
        contract.setSubAccountMarginType(ts, ts, subID, MarginType.PORTFOLIO_CROSS_MARGIN, salt, sig, {
          gasLimit: MAX_GAS,
        })
      ).to.be.reverted
      // TODO "invalid signature"
    })

    it("fails no permission", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      // Add subaccount signer without any permission
      const alice = wallet()
      ts++
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.None)).not.to.be.reverted

      // Try to add another subaccount signer from
      const bob = wallet()
      ts++
      await expect(addSubSigner(contract, ts, ts, alice, subID, bob.address, SubPerm.None)).to.be.reverted
    })

    // This is invalid
    // it.only("fails if the signer is already a subaccount signer", async function () {
    //   // Setup
    //   const admin = wallet()
    //   const accID = admin.address

    //   let ts = 1
    //   await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

    //   ts++
    //   const subID = 1
    //   await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

    //   // Test
    //   const signer = wallet().address
    //   ts++
    //   await expect(addSubSigner(contract, ts, ts, admin, subID, signer, 1)).not.to.be.reverted

    //   ts++
    //   await expect(addSubSigner(contract, ts, ts, admin, subID, signer, 1)).to.be.reverted
    // })
  })

  describe("SetSubAccountSignerPermissions", function () {
    it("acc-admin/sub-account-admin/signer-with-permission can change permission of subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)).not.to.be.reverted

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await expect(
        addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.UpdateSignerPermission | SubPerm.Trade)
      ).not.to.be.reverted

      ts++
      // Least privilege signer
      const carl = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, carl.address, SubPerm.Withdrawal)).not.to.be.reverted

      // Test
      ts++
      // account admin can change permission of any signer
      await expect(setSubAccountSignerPermission(contract, admin, ts, ts, subID, carl.address, SubPerm.Deposit)).not.to
        .be.reverted

      ts++
      // subaccount admin can change permission of any signer
      await expect(setSubAccountSignerPermission(contract, alice, ts, ts, subID, carl.address, SubPerm.Admin)).not.to.be
        .reverted

      ts++
      // subaccount signer with update permission can change permission of any signer
      await expect(setSubAccountSignerPermission(contract, bob, ts, ts, subID, carl.address, SubPerm.Trade)).not.to.be
        .reverted
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1

      // Test
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(setSubAccountSignerPermission(contract, admin, ts, ts, subID, admin.address, SubPerm.Trade)).to.be
        .reverted
    })

    it("fails if new permission is more privileged than current user's permission", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      const alice = wallet()
      ts++
      await expect(
        addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Trade | SubPerm.UpdateSignerPermission)
      ).not.to.be.reverted

      const bob = wallet()
      ts++
      await expect(addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Withdrawal)).not.to.be.reverted

      // Test
      ts++
      await expect(setSubAccountSignerPermission(contract, alice, ts, ts, subID, bob.address, SubPerm.Admin)).to.be
        .reverted
      // TODO "actor cannot grant permission"

      await expect(setSubAccountSignerPermission(contract, alice, ts, ts, subID, bob.address, SubPerm.Deposit)).to.be
        .reverted
      // TODO "actor cannot grant permission"
    })

    it.skip("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      // Test
      ts++
      // account admin can change permission of any signer
      const salt = nonce()
      const sig = genSetSubAccountSignerPermissionsPayloadSig(admin, subID, alice.address, SubPerm.Trade, salt)
      await expectToThrowAsync(
        contract.SetSubAccountSignerPermissions(ts, ts, subID, alice.address, SubPerm.Deposit, salt, sig),
        "invalid signature"
      )
    })

    it("fails if current user doesn't have permission to update", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Trade)).not.to.be.reverted

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Trade)).not.to.be.reverted

      // Test
      ts++
      await expect(setSubAccountSignerPermission(contract, alice, ts, ts, subID, bob.address, SubPerm.Deposit)).to.be
        .reverted
      // TODO "actor cannot call function"
    })
  })

  describe("removeSubAccountSigner", function () {
    it("account admin can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)).not.to.be.reverted

      // Test
      ts++
      await expect(removeSubSigner(contract, admin, ts, ts, subID, alice.address)).not.to.be.reverted
    })

    it("subaccount admin can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)).not.to.be.reverted

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await expect(
        addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.UpdateSignerPermission | SubPerm.Trade)
      ).not.to.be.reverted

      // Test
      ts++
      await expect(removeSubSigner(contract, alice, ts, ts, subID, bob.address)).not.to.be.reverted
    })

    it("user with removal permission can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.RemoveSigner)).not.to.be.reverted

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Deposit)).not.to.be.reverted

      // Test
      ts++
      await expect(removeSubSigner(contract, alice, ts, ts, subID, bob.address)).not.to.be.reverted
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      let ts = 1
      // SubAccount admin
      const alice = wallet()
      // Test
      await expect(removeSubSigner(contract, admin, ts, ts, subID, alice.address)).to.be.reverted
      // TODO"subaccount does not exist"
    })

    it.skip("fails if subaccount signer doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)
      // SubAccount admin
      const alice = wallet()
      // Test
      ts++
      await expectToThrowAsync(removeSubSigner(contract, admin, ts, ts, subID, alice.address), "signer not found")
    })

    it.skip("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)
      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)
      // Test
      ts++
      // account admin can change permission of any signer
      const salt = nonce()
      const sig = genRemoveSubAccountSignerPayloadSig(admin, subID, alice.address, salt)
      await expectToThrowAsync(
        contract.removeSubAccountSigner(ts, ts, subID, alice.address, salt + 1, sig),
        "invalid signature"
      )
    })

    it("fails if current user doesn't have permission to remove", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await expect(createAccount(contract, admin, ts, ts, accID)).not.to.be.reverted

      ts++
      await expect(createSubAccount(contract, admin, ts, ts, accID, subID)).not.to.be.reverted

      ts++
      // SubAccount admin
      const alice = wallet()
      await expect(addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)).not.to.be.reverted

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await expect(
        addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.UpdateSignerPermission | SubPerm.Trade)
      ).not.to.be.reverted

      // Test
      ts++
      await expect(removeSubSigner(contract, bob, ts, ts, subID, alice.address)).to.be.reverted
      // TODO "no permission"
    })
  })
})
