import { Contract } from "ethers"
import { network } from "hardhat"
import { deployContract } from "../deploy/utils"
import { createAccount, markPriceTick, setConfig } from "./api"
import { bytes32, getDeployerWallet, wallet } from "./util"
import { ConfigID, PriceEntry } from "./type"
import { CONFIG_WALLET_PK } from "./default"
import { toAssetID } from "./engine/util"

const TRUE_CONFIG_VALUE = bytes32(1)

describe.only("API - Oracle", function () {
  let contract: Contract
  let snapshotId: string
  const configWallet = wallet(CONFIG_WALLET_PK)
  let ts: number

  before(async () => {
    const wallet = getDeployerWallet()
    contract = await deployContract("GRVTExchange", [], { wallet, silent: true, noVerify: true })
    // Initialise
    const tx = await contract.initialize()
    await tx
  })

  beforeEach(async () => {
    snapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshotId])
  })

  it("update 2000 mark prices", async () => {
    // Update oracle address
    ts = 1
    const oracle = wallet()
    const oracleAddress = bytes32(oracle)
    console.log("configAddr", configWallet.address)
    await setConfig(contract, configWallet, ts, ts, ConfigID.ORACLE_ADDRESS, oracleAddress, TRUE_CONFIG_VALUE)

    // Prepare the payload for 2000 mark prices
    ts++
    const prices: PriceEntry[] = []
    const numPrices = 700
    for (let i = 0; i < numPrices; i++) {
      const assetID = toAssetID({
        kind: Math.random() < 0.5 ? "CALL" : "PUT",
        underlying: "ETH",
        quote: "USD",
        expiration: randomBigInt(10, 20).toString(),
        strike_price: randomBigInt(3e9, 4e9).toString(),
      })
      prices.push({
        assetID,
        value: BigInt(Math.floor(Math.random() * 100000)),
      })
    }
    await markPriceTick(contract, configWallet, ts, ts, prices, BigInt(ts))

    // Call the contract
  })
})

function randomBigInt(a: number, b: number) {
  return BigInt(Math.floor(Math.random() * (b - a + 1) + a))
}
