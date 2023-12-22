// import { ethers } from "hardhat"
// import { GRVTExchange } from "../typechain-types"
// import {
//   addAccAdmin,
//   addAccGuardian,
//   addSubSigner,
//   createSubAcc,
//   recoverAccAdmin,
//   removeAccGuardian,
//   setMultisigThreshold,
// } from "./api"
// import {
//   genAddAccountGuardianPayloadSig,
//   genRecoverAccountAdminPayloadSig,
//   genRemoveAccountGuardianPayloadSig,
// } from "./signature"
// import { AccountRecoveryType, ConfigID } from "./type"
// import { Bytes32, bytes32, expectToThrowAsync, getConfigArray, nonce, wallet } from "./util"

// describe("API - AccountRecovery", function () {
//   let contract: GRVTExchange
//   const grvt = wallet()

//   beforeEach(async () => {
//     const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
//     contract = <GRVTExchange>await ethers.deployContract("GRVTExchange", [config])
//   })

//   describe("addAccountGuardian", function () {
//     it("can add guardian successfully", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian = wallet().address
//       ts++
//       await addAccGuardian(contract, [admin], ts, ts, accID, guardian)

//       // Test: 2 admins
//       const guardian2 = wallet().address
//       const alice = wallet()
//       ts++
//       await addAccAdmin(contract, [admin], ts, ts, accID, alice.address)

//       // Update quorum to 2
//       ts++
//       await setMultisigThreshold(contract, [admin], ts, ts, accID, 2)

//       ts++
//       await addAccGuardian(contract, [admin, alice], ts, ts, accID, guardian2)
//     })

//     it("fails if signer is not an admin", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet().address
//       ts++
//       await expectToThrowAsync(addAccGuardian(contract, [wallet()], ts, ts, accID, guardian), "ineligible signer")
//     })

//     it("fails if account does not exist", async function () {
//       const accID = 1
//       let ts = 1

//       // Test
//       const guardian = wallet().address
//       await expectToThrowAsync(addAccGuardian(contract, [wallet()], ts, ts, accID, guardian), "account does not exist")
//     })

//     it("fails if invalid signature", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian = wallet().address
//       ts++
//       const salt = nonce()
//       const sig = genAddAccountGuardianPayloadSig(admin, accID, guardian, salt + 1)
//       await expectToThrowAsync(contract.addAccountGuardian(ts, ts, accID, guardian, salt, [sig]), "invalid signature")
//     })

//     it("fails if quorum is not met", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet().address
//       const alice = wallet()
//       ts++
//       await addAccAdmin(contract, [admin], ts, ts, accID, alice.address)

//       // Update quorum to 2
//       ts++
//       await setMultisigThreshold(contract, [admin], ts, ts, accID, 2)

//       ts++
//       await expectToThrowAsync(addAccGuardian(contract, [admin], ts, ts, accID, guardian), "failed quorum")
//     })

//     it("fails if guardian already exists", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian = wallet().address
//       ts++
//       await addAccGuardian(contract, [admin], ts, ts, accID, guardian)
//       ts++
//       await expectToThrowAsync(addAccGuardian(contract, [admin], ts, ts, accID, guardian), "address exists")
//     })
//   })

//   describe("removeAccountGuardian", function () {
//     it("admin can remove guardian successfully, quorum=1", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian = wallet().address
//       ts++
//       await addAccGuardian(contract, [admin], ts, ts, accID, guardian)

//       ts++
//       await removeAccGuardian(contract, [admin], ts, ts, accID, guardian)
//     })

//     it("admin can remove guardian successfully, quorum=2", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet().address
//       ts++
//       await addAccGuardian(contract, [admin], ts, ts, accID, guardian)

//       const alice = wallet()
//       ts++
//       await addAccAdmin(contract, [admin], ts, ts, accID, alice.address)

//       // Update quorum to 2
//       ts++
//       await setMultisigThreshold(contract, [admin], ts, ts, accID, 2)

//       ts++
//       await removeAccGuardian(contract, [admin, alice], ts, ts, accID, guardian)
//     })

//     it("fails if signer is not an admin", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet().address
//       ts++
//       await expectToThrowAsync(removeAccGuardian(contract, [wallet()], ts, ts, accID, guardian), "ineligible signer")
//     })

//     it("fails if account does not exist", async function () {
//       const accID = 1
//       let ts = 1

//       // Test
//       const guardian = wallet().address
//       await expectToThrowAsync(
//         removeAccGuardian(contract, [wallet()], ts, ts, accID, guardian),
//         "account does not exist"
//       )
//     })

//     it("fails if invalid signature", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian = wallet().address
//       ts++
//       const salt = nonce()
//       const sig = genRemoveAccountGuardianPayloadSig(admin, accID, guardian, salt + 1)
//       await expectToThrowAsync(
//         contract.removeAccountGuardian(ts, ts, accID, guardian, salt, [sig]),
//         "invalid signature"
//       )
//     })

//     it("fails if quorum is not met", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet().address
//       const alice = wallet()
//       ts++
//       await addAccAdmin(contract, [admin], ts, ts, accID, alice.address)

//       // Update quorum to 2
//       ts++
//       await setMultisigThreshold(contract, [admin], ts, ts, accID, 2)

//       ts++
//       await expectToThrowAsync(removeAccGuardian(contract, [admin], ts, ts, accID, guardian), "failed quorum")
//     })

//     it("fails if guardian does not exists", async function () {
//       // Setup
//       const admin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, admin, ts, ts, accID, subID)

//       // Test: 1 admin
//       const guardian2 = wallet().address
//       ts++
//       await expectToThrowAsync(removeAccGuardian(contract, [admin], ts, ts, accID, guardian2), "not found")
//     })
//   })

//   describe("recoverAccountAdmin", function () {
//     it("can recover using guardian accounts", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, oldAdmin, ts, ts, accID, subID)

//       // Add guardian
//       const guardian = wallet()
//       ts++
//       await addAccGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)

//       ts++
//       await recoverAccAdmin(
//         contract,
//         [guardian],
//         ts,
//         ts,
//         accID,
//         AccountRecoveryType.GUARDIAN,
//         oldAdmin.address,
//         newAdmin.address
//       )
//     })

//     it("can recover using subaccount signers", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, oldAdmin, ts, ts, accID, subID)

//       // Add signer
//       const signer = wallet()
//       ts++
//       addSubSigner(contract, ts, ts, oldAdmin, subID, signer.address, 1)

//       ts++
//       await recoverAccAdmin(
//         contract,
//         [signer],
//         ts,
//         ts,
//         accID,
//         AccountRecoveryType.SUB_ACCOUNT_SIGNERS,
//         oldAdmin.address,
//         newAdmin.address
//       )
//     })

//     it("fails if invalid signature", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, oldAdmin, ts, ts, accID, subID)

//       // Add guardian
//       const guardian = wallet()
//       ts++
//       await addAccGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)

//       ts++
//       const salt = nonce()
//       const sigs = [
//         genRecoverAccountAdminPayloadSig(
//           guardian,
//           accID,
//           AccountRecoveryType.GUARDIAN,
//           oldAdmin.address,
//           newAdmin.address,
//           salt
//         ),
//       ]
//       await expectToThrowAsync(
//         contract.recoverAccountAdmin(
//           ts,
//           ts,
//           accID,
//           AccountRecoveryType.GUARDIAN,
//           oldAdmin.address,
//           newAdmin.address,
//           salt + 2,
//           sigs
//         ),
//         "invalid signature"
//       )
//     })

//     it("fails if account does not exist", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const accID = 1
//       let ts = 1

//       await expectToThrowAsync(
//         recoverAccAdmin(
//           contract,
//           [wallet()],
//           ts,
//           ts,
//           accID,
//           AccountRecoveryType.GUARDIAN,
//           oldAdmin.address,
//           newAdmin.address
//         ),
//         "account does not exist"
//       )
//     })

//     it("fails if quorum is not met", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, oldAdmin, ts, ts, accID, subID)

//       // Add 2 guardians, quorum should be 2 votes to be able to recover
//       const guardian = wallet()
//       const guardian2 = wallet()
//       ts++
//       await addAccGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)
//       ts++
//       await addAccGuardian(contract, [oldAdmin], ts, ts, accID, guardian2.address)

//       ts++
//       await expectToThrowAsync(
//         recoverAccAdmin(
//           contract,
//           [guardian],
//           ts,
//           ts,
//           accID,
//           AccountRecoveryType.GUARDIAN,
//           oldAdmin.address,
//           newAdmin.address
//         ),
//         "failed quorum"
//       )
//     })

//     it("fails if signer is not guardian or subaccount signer", async function () {
//       // Setup
//       const oldAdmin = wallet()
//       const newAdmin = wallet()
//       const subID = wallet().address
//       const accID = 1
//       let ts = 1
//       await createSubAcc(contract, oldAdmin, ts, ts, accID, subID)

//       // Test
//       const guardian = wallet()
//       ts++
//       await addAccGuardian(contract, [oldAdmin], ts, ts, accID, guardian.address)

//       ts++
//       await expectToThrowAsync(
//         recoverAccAdmin(
//           contract,
//           [wallet()],
//           ts,
//           ts,
//           accID,
//           AccountRecoveryType.GUARDIAN,
//           oldAdmin.address,
//           newAdmin.address
//         ),
//         "ineligible signer"
//       )
//     })
//   })
// })
