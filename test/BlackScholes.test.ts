import { Contract } from "ethers"
import { ethers } from "hardhat"

describe.only("BlackScholes", function () {
  let contract: Contract

  beforeEach(async () => {
    const bsFactory = await ethers.getContractFactory("BlackScholes")
    const bs = await bsFactory.deploy()
    const factory = await ethers.getContractFactory("GRVTExchange", {
      libraries: {
        BlackScholes: bs.address,
      },
    })
    contract = await factory.deploy()
  })

  it("Call Put", async function () {
    const [call, put] = await contract.bs()
    console.log(call, put)
  })
})
