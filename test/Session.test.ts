// import { ethers } from "hardhat"
// import { GRVTExchange } from "../typechain-types"
// import { ConfigID } from "./type"
// import { Bytes32, bytes32, getConfigArray, getTimestampNs, wallet } from "./util"
// import { addSessionKey, removeSessionKey } from "./api"

// describe("API - Session Key", function () {
//   let contract: GRVTExchange
//   const grvt = wallet()

//   beforeEach(async () => {
//     const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
//     contract = <GRVTExchange>await ethers.deployContract("GRVTExchange", [config])
//   })

//   describe("addSessionKey", () => {
//     it("should add session key", async () => {
//       const signer = wallet()
//       let ts = 1
//       await addSessionKey(contract, signer, ts, ts, wallet().address, getTimestampNs(1))
//     })
//   })

//   describe("removeSessionKey", () => {
//     it("should remove session key", async () => {
//       const signer = wallet()
//       let ts = 1
//       await addSessionKey(contract, signer, ts, ts, wallet().address, Date.now())
//       ts++
//       await removeSessionKey(contract, signer, ts, ts)
//     })

//     it("noop if remove non-existent session key", async () => {
//       const signer = wallet()
//       let ts = 1
//       await removeSessionKey(contract, signer, ts, ts)
//     })
//   })
// })
