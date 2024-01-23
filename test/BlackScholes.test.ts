// import { Contract } from "ethers"
// import { ethers } from "hardhat"
// import { GRVTExchange } from "../typechain-types"
// import { Bytes32, bytes32, getConfigArray, wallet } from "./util"
// import { ConfigID } from "./type"

// describe("BlackScholes", function () {
//   let contract: Contract
//   const grvt = wallet()

//   beforeEach(async () => {
//     const config = getConfigArray(new Map<number, Bytes32>([[ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)]]))
//     contract = await ethers.deployContract("GRVTExchange", [config])
//   })

//   // beforeEach(async () => {
//   //   const bsFactory = await ethers.getContractFactory("BlackScholes")
//   //   const bs = await bsFactory.deploy()
//   //   const factory = await ethers.getContractFactory("GRVTExchange", {
//   //     // libraries: {
//   //     //   BlackScholes: bs.address,
//   //     // },
//   //   })
//   //   contract = await factory.deploy()
//   // })

//   it("Call Put", async function () {
//     await contract.bs()
//     // console.log(call, put)
//   })
// })
