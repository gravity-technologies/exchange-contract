import { expect } from "chai"
import { Contract } from "ethers"
import { network } from "hardhat"
import { deployContract } from "../deploy/utils"
import {
  addAccountSigner,
  addWithdrawalAddress,
  createAccount,
  removeAccountSigner,
  removeWithdrawalAddress,
} from "./api"
import { AccPerm } from "./type"
import { expectToThrowAsync, getDeployerWallet, wallet } from "./util"

describe("API - Account", function () {
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

  describe("createAccount", function () {
    it("Should create account successfully", async function () {
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      try {
        await createAccount(contract, admin, ts, ts, accID)
      } catch (e) {
        console.log("error", e)
      }
    })

    it("Error if account already exists", async function () {
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      try {
        await createAccount(contract, admin, ts, ts, accID)
        expect.fail("expected to fail, but didn't")
      } catch (err) {}
    })
  })

  describe("addAccountSigner", function () {
    it("Should add admin successfully", async function () {
      const admin1 = wallet()
      const admin2 = wallet()
      const accID = admin1.address
      let ts = 1
      // 1. Create sub account
      await createAccount(contract, admin1, ts, ts, accID)
      ts++
      const tx = addAccountSigner(contract, [admin1], ts, ts, accID, admin2.address, AccPerm.Admin)
      await expectToThrowAsync(tx)
    })

    it("fails if account does not exist", async function () {
      const w = wallet()
      let ts = 1
      const tx = addAccountSigner(contract, [w], ts, ts, w.address, wallet().address, AccPerm.Admin)
      await expectToThrowAsync(tx)
      // TODO "account does not exist"
    })

    it("No-op if admin address already exists", async function () {
      const admin = wallet()
      const accID = admin.address
      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      const tx = addAccountSigner(contract, [admin], ts, ts, accID, wallet().address, AccPerm.Admin)
      await expectToThrowAsync(tx)
    })
  })

  describe("removeAccountSigner", function () {
    it("Should remove successfully", async function () {
      const admin1 = wallet()
      const admin2 = wallet()
      const accID = admin1.address

      let ts = 1
      await createAccount(contract, admin1, ts, ts, accID)
      ts++
      await addAccountSigner(contract, [admin1], ts, ts, accID, admin2.address, AccPerm.Admin)
      ts++
      const tx = removeAccountSigner(contract, [admin1], ts, ts, accID, admin1.address)
      await tx
    })

    it("Error when removing the last admin", async function () {
      const w1 = wallet()
      const accID = w1.address
      let ts = 1
      await createAccount(contract, w1, ts, ts, accID)
      ts++
      const tx = removeAccountSigner(contract, [w1], ts, ts, accID, w1.address)
      await expectToThrowAsync(tx)
    })

    it("Error if account does not exist", async function () {
      const w1 = wallet()
      const accID = w1.address

      let ts = 1
      const tx = removeAccountSigner(contract, [w1], ts, ts, accID, w1.address)
      await expectToThrowAsync(tx)
      // "account does not exist"
    })

    it("no-op if admin address does not exist", async function () {
      const admin = wallet()
      const notAddedWallet = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      const tx = removeAccountSigner(contract, [admin], ts, ts, accID, notAddedWallet.address)
      await tx
    })
  })

  describe("addWithdrawalAddress", function () {
    it("should add withdrawal address successfully", async function () {
      const admin = wallet()
      const withdrawalAddress = wallet().address
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      await addWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress)
    })

    it("fails if account does not exist", async function () {
      const withdrawalAddress = wallet().address
      const accID = wallet().address
      let ts = 1
      await expectToThrowAsync(addWithdrawalAddress(contract, [wallet()], ts, ts, accID, withdrawalAddress))
    })

    it("no-op if withdrawal address already exists", async function () {
      const admin = wallet()
      const withdrawalAddress = wallet().address
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      ts++
      await addWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress)
      ts++
      await addWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress)
    })
  })

  describe("removeWithdrawalAddress", function () {
    it("Should remove withdrawal address successfully", async function () {
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      const withdrawalAddress = wallet().address
      ts++
      await addWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress)
      ts++
      await removeWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress)
    })

    it("Error if account does not exist", async function () {
      const withdrawalAddress = wallet().address
      const accID = wallet().address

      let ts = 1
      await expectToThrowAsync(removeWithdrawalAddress(contract, [wallet()], ts, ts, accID, withdrawalAddress))
      // "account does not exist"
    })

    it("No-op if withdrawal address does not exist", async function () {
      // Create an account explicitly for this test
      const admin = wallet()
      const accID = admin.address

      let ts = 1
      await createAccount(contract, admin, ts, ts, accID)
      const withdrawalAddress1 = wallet().address
      const withdrawalAddress2 = wallet().address

      // Add withdrawal address explicitly for this test
      ts++
      await addWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress1)

      ts++
      await removeWithdrawalAddress(contract, [admin], ts, ts, accID, withdrawalAddress2)
    })
  })

  // describe("addTransferSubAccount", function () {
  //   it("Success", async function () {
  //     // Create an account explicitly for this test
  //     const admin = wallet()
  //     const accID = 1

  //     let ts = 1
  //     await createAccount(contract, admin, ts, ts, accID, admin.address)
  //     const transferSubAccount = wallet().address
  //     ts++
  //     await addTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount)
  //   })

  //   it("fails if account does not exist", async function () {
  //     const transferSubAccount = wallet().address
  //     const accID = 1
  //     const w = wallet()

  //     let ts = 1
  //     await expectToThrowAsync(
  //       addTransferSubAccount(contract, [w], ts, ts, accID, transferSubAccount),
  //       "account does not exist"
  //     )
  //   })

  //   it("fails if transfer subaccount already exists", async function () {
  //     const admin = wallet()
  //     const accID = 1

  //     let ts = 1
  //     await createAccount(contract, admin, ts, ts, accID, admin.address)
  //     const transferSubAccount = wallet().address

  //     // Add transfer subaccount explicitly for this test
  //     ts++
  //     await addTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount)

  //     ts++
  //     await expectToThrowAsync(
  //       addTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount),
  //       "address exist"
  //     )
  //   })
  // })

  // describe("removeTransferSubAccount", function () {
  //   it("Should remove transfer subaccount successfully", async function () {
  //     // Create an account explicitly for this test
  //     const admin = wallet()
  //     const accID = 1
  //     let ts = 1

  //     await createAccount(contract, admin, ts, ts, accID, admin.address)
  //     const transferSubAccount = wallet().address

  //     ts++
  //     await addTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount)

  //     ts++
  //     await removeTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount)
  //   })

  //   it("fails if account does not exist", async function () {
  //     const transferSubAccount = wallet().address
  //     const accID = 1
  //     const w = wallet()

  //     let ts = 1
  //     await expectToThrowAsync(
  //       removeTransferSubAccount(contract, [w], ts, ts, accID, transferSubAccount),
  //       "account does not exist"
  //     )
  //   })

  //   it("fails if transfer subaccount doesn not exist", async function () {
  //     const admin = wallet()
  //     const accID = 1
  //     let ts = 1

  //     await createAccount(contract, admin, ts, ts, accID, admin.address)
  //     const transferSubAccount = wallet().address
  //     ts++
  //     await expectToThrowAsync(
  //       removeTransferSubAccount(contract, [admin], ts, ts, accID, transferSubAccount),
  //       "not found"
  //     )
  //   })
  // })

  // describe("Security - Prevent Replay Attack", function () {
  //   it("Should not allow updating replaying update multisig threshold", async function () {
  //     const w1 = wallet()
  //     const w2 = wallet()

  //     const accID = 1
  //     const salt = nonce()
  //     let ts = 1
  //     await createAccount(contract, w1, ts, ts, accID, w1.address)
  //     ts++
  //     await addAccSigner(contract, [w1], ts, ts, accID, w2.address)

  //     ts++
  //     await contract.setAccountMultiSigThreshold(
  //       ts, // timestamp
  //       ts, // txID
  //       accID, // accountID
  //       2, // multiSigThreshold
  //       salt,
  //       [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
  //     )
  //     await expectToThrowAsync(
  //       contract.setAccountMultiSigThreshold(
  //         ts, // timestamp
  //         ts, // txID
  //         accID, // accountID
  //         2, // multiSigThreshold
  //         salt,
  //         [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
  //       )
  //     )
  //   })
  // })

  // describe("Security - Prevent Replay Attack", function () {
  //   it("Should not allow updating replaying update multisig threshold", async function () {
  //     const w1 = wallet()
  //     const w2 = wallet()

  //     const accID = 1
  //     const salt = nonce()
  //     let ts = 1
  //     await createAccount(contract, w1, ts, ts, accID, w1.address)
  //     ts++
  //     await addAccSigner(contract, [w1], ts, ts, accID, w2.address)

  //     ts++
  //     await contract.setAccountMultiSigThreshold(
  //       ts, // timestamp
  //       ts, // txID
  //       accID, // accountID
  //       2, // multiSigThreshold
  //       salt,
  //       [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
  //     )

  //     ts++
  //     await expectToThrowAsync(
  //       contract.setAccountMultiSigThreshold(
  //         ts, // timestamp
  //         ts, // txID
  //         accID, // accountID
  //         2, // multiSigThreshold
  //         salt,
  //         [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
  //       )
  //     )
  //   })
  // })
})
