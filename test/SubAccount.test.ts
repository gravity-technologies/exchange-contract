import { Contract } from "ethers"
import { network } from "hardhat"
import { deployContract } from "../deploy/utils"
import { MAX_GAS, addSubSigner, createAccount, createSubAccount, removeSubSigner, setSubAccountMarginType } from "./api"
import {
  genAddSubAccountSignerPayloadSig,
  genRemoveSubAccountSignerPayloadSig,
  genSetSubAccountMarginTypePayloadSig,
} from "./signature"
import { MarginType, SubPerm } from "./type"
import { expectToThrowAsync, getDeployerWallet, nonce, wallet } from "./util"

describe("API - SubAccount", function () {
  let contract: Contract
  let snapshotId: string

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

  describe("createSubAccount", function () {
    it("Should create subaccount successfully", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)
    })

    it("Error if account doesn't exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      const subID = 1
      await expectToThrowAsync(createSubAccount(contract, admin, ts, ts, accID, subID))
    })

    it("Error if subaccount already exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      await expectToThrowAsync(createSubAccount(contract, admin, ts, ts, accID, subID))
    })
  })

  describe("setSubAccountMarginType", function () {
    it("admin can switch margin type", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      await setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED)
    })

    it("signer with permission can switch margin type", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1
      const alice = wallet()

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      // Test
      ts++
      await setSubAccountMarginType(contract, alice, ts, ts, subID, MarginType.ISOLATED)
    })

    it("fails if user doesn't have permission", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      const subID = 1
      const alice = wallet()

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      await expectToThrowAsync(setSubAccountMarginType(contract, alice, ts, ts, subID, MarginType.ISOLATED))
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
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      const signer = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, signer.address, SubPerm.Trade)
    })

    it("fails if subaccount doesn't exists", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await expectToThrowAsync(setSubAccountMarginType(contract, admin, ts, ts, subID, MarginType.ISOLATED))
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      ts++
      const salt = nonce()
      const sig = genSetSubAccountMarginTypePayloadSig(admin, subID, MarginType.ISOLATED, salt)
      await expectToThrowAsync(
        contract.setSubAccountMarginType(ts, ts, subID, MarginType.PORTFOLIO_CROSS_MARGIN, salt, sig, {
          gasLimit: MAX_GAS,
        })
      )
      // TODO "invalid signature"
    })

    it("fails no permission", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Add subaccount signer without any permission
      const alice = wallet()
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.None)

      // Try to add another subaccount signer from
      const bob = wallet()
      ts++
      await expectToThrowAsync(addSubSigner(contract, ts, ts, alice, subID, bob.address, SubPerm.None))
    })

    // This is invalid
    it("fails if the signer is already a subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      const subID = 1
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      // Test
      const signer = wallet().address
      ts++
      await addSubSigner(contract, ts, ts, admin, subID, signer, 1)

      ts++
      await expectToThrowAsync(addSubSigner(contract, ts, ts, admin, subID, signer, 1))
    })
  })

  describe("SetSubAccountSignerPermissions", function () {
    it("acc-admin/sub-account-admin can change permission of subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Admin | SubPerm.Trade)

      ts++
      // Least privilege signer
      const carl = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, carl.address, SubPerm.None)

      // Test
      ts++
      // account admin can change permission of any signer
      await addSubSigner(contract, ts, ts, admin, subID, carl.address, SubPerm.Trade)

      ts++
      // subaccount admin can change permission of any signer
      await addSubSigner(contract, ts, ts, alice, subID, carl.address, SubPerm.Admin)

      ts++
      // subaccount signer with update permission can change permission of any signer
      await addSubSigner(contract, ts, ts, bob, subID, carl.address, SubPerm.Trade)
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const accID = wallet().address
      const subID = 1

      // Test
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await expectToThrowAsync(addSubSigner(contract, ts, ts, admin, subID, admin.address, SubPerm.Trade))
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++

      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      // Test
      ts++
      // account admin can change permission of any signer
      const salt = nonce()
      const sig = genAddSubAccountSignerPayloadSig(admin, subID, alice.address, SubPerm.Trade, salt)
      await expectToThrowAsync(
        contract.addSubAccountSigner(ts, ts, subID, alice.address, SubPerm.Trade, salt, sig),
        "invalid signature"
      )
    })

    it("fails if current user doesn't have permission to update", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Trade)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Trade)

      // Test
      ts++
      await expectToThrowAsync(addSubSigner(contract, ts, ts, alice, subID, bob.address, SubPerm.Trade))
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
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      // Test
      ts++
      await removeSubSigner(contract, admin, ts, ts, subID, alice.address)
    })

    it("subaccount admin can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Trade)

      // Test
      ts++
      await removeSubSigner(contract, alice, ts, ts, subID, bob.address)
    })

    it("user with admin permission can remove subaccount signer", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Trade)

      // Test
      ts++
      await removeSubSigner(contract, alice, ts, ts, subID, bob.address)
    })

    it("fails if subaccount doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      let ts = 1
      // SubAccount admin
      const alice = wallet()
      // Test
      await expectToThrowAsync(removeSubSigner(contract, admin, ts, ts, subID, alice.address))
      // TODO"subaccount does not exist"
    })

    it("fails if subaccount signer doesn't exist", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)
      // SubAccount admin
      const alice = wallet()
      // Test
      ts++
      await expectToThrowAsync(removeSubSigner(contract, admin, ts, ts, subID, alice.address), "signer not found")
    })

    it("fails if invalid signature", async function () {
      // Setup
      const admin = wallet()
      const subID = 1
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
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
      await createAccount(contract, admin, ts, ts, accID)

      ts++
      await createSubAccount(contract, admin, ts, ts, accID, subID)

      ts++
      // SubAccount admin
      const alice = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, alice.address, SubPerm.Admin)

      ts++
      // SubAccount signer with update permission
      const bob = wallet()
      await addSubSigner(contract, ts, ts, admin, subID, bob.address, SubPerm.Trade)

      // Test
      ts++
      await expectToThrowAsync(removeSubSigner(contract, bob, ts, ts, subID, alice.address))
      // TODO "no permission"
    })
  })
})
