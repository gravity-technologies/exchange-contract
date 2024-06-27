// import { ethers } from "hardhat"
// import { TradeTestPrep } from "../../typechain-types"
// import { ConfigID, Order, OrderLeg, OrderMatch, OrderNoSignature, TimeInForce, Trade } from "../type"
// import { Bytes32, bytes32, getConfigArray, nonce, wallet } from "../util"
// import { Wallet } from "ethers"
// import { genOrderSig } from "../signature"

// describe.only("API - Trade", function () {
//   let contract: TradeTestPrep
//   const grvt = wallet()

//   // const takerAccID = 1
//   const taker = new Wallet("0xac209314b7e995b30103d39aa4f2f7adf16c82acf15891ba45965eafd00e84df")
//   // const makerAccID = 2
//   const maker = new Wallet("0x4698d89b8bc50606f68abdff32443d418ac25eb1adc7d4ca195d77ab836a29ae")
//   const derivID = "0x1234"
//   const feeWallet = new Wallet("0x7c4978a1147256ecd75161c96fc40fb08a26672fbb9497b2505ec873cdf9e6e8")

//   beforeEach(async () => {
//     const config = getConfigArray(
//       new Map<number, Bytes32>([
//         [ConfigID.ADMIN_RECOVERY_ADDRESS, bytes32(grvt)],
//         [ConfigID.FEE_SUB_ACCOUNT_ID, bytes32(feeWallet)],
//       ])
//     )
//     contract = <TradeTestPrep>await ethers.deployContract("TradeTestPrep", [config])
//   })

//   it("OrderSig", async function () {
//     const taker2 = new Wallet("0xec16962ad953e803281e6916110d0101a07b88346c595510a2117b131a4475e3")
//     const takerOrder: OrderNoSignature = {
//       subAccountID: taker2.address,
//       isMarket: true,
//       timeInForce: TimeInForce.GOOD_TILL_TIME,
//       limitPrice: 224488,
//       ocoLimitPrice: 336699,
//       takerFeePercentageCap: 70,
//       makerFeePercentageCap: 80,
//       postOnly: false,
//       reduceOnly: false,
//       isPayingBaseCurrency: true,
//       legs: [
//         {
//           derivative: derivID,
//           contractSize: 5,
//           limitPrice: 3344,
//           ocoLimitPrice: 5566,
//           isBuyingContract: true,
//         },
//       ],
//       nonce: 22021991,
//     }
//     genOrderSig(taker2, takerOrder)
//   })

//   // it("Happy path: can trade successfully", async function () {
//   //   // ----------------------------------------------
//   //   // Accounts
//   //   // ----------------------------------------------

//   //   // ----------------------------------------------
//   //   // Order
//   //   // ----------------------------------------------
//   //   const takerOrder: OrderNoSignature = {
//   //     subAccountID: taker.address,
//   //     isMarket: false,
//   //     timeInForce: TimeInForce.ALL_OR_NONE,
//   //     limitPrice: 1000,
//   //     ocoLimitPrice: 1001,
//   //     takerFeePercentageCap: 1,
//   //     makerFeePercentageCap: 1,
//   //     postOnly: false,
//   //     reduceOnly: false,
//   //     isPayingBaseCurrency: true,
//   //     legs: [
//   //       {
//   //         derivative: derivID,
//   //         contractSize: 10,
//   //         limitPrice: 100,
//   //         ocoLimitPrice: 101,
//   //         isBuyingContract: true,
//   //       },
//   //     ],
//   //     nonce: nonce(),
//   //   }

//   //   const makerOrder: OrderNoSignature = {
//   //     subAccountID: maker.address,
//   //     isMarket: false,
//   //     timeInForce: TimeInForce.ALL_OR_NONE,
//   //     limitPrice: 1000,
//   //     ocoLimitPrice: 1001,
//   //     takerFeePercentageCap: 1,
//   //     makerFeePercentageCap: 1,
//   //     postOnly: false,
//   //     reduceOnly: false,
//   //     isPayingBaseCurrency: true,
//   //     legs: [
//   //       {
//   //         derivative: derivID,
//   //         contractSize: 3,
//   //         limitPrice: 100,
//   //         ocoLimitPrice: 103,
//   //         isBuyingContract: false,
//   //       },
//   //     ],
//   //     nonce: nonce(),
//   //   }
//   //   const trade: Trade = {
//   //     takerOrder: getOrderWithSig(taker, takerOrder),
//   //     makerOrders: [
//   //       {
//   //         makerOrder: getOrderWithSig(maker, makerOrder),
//   //         numContractsMatched: [1],
//   //         takerFeePercentageCharged: 100,
//   //         makerFeePercentageCharged: 100,
//   //       },
//   //     ],
//   //   }

//   //   // ----------------------------------------------
//   //   // Trade
//   //   // ----------------------------------------------
//   //   let ts = 1
//   //   await contract.trade(ts, ts, trade)
//   // })

//   // // Sub account and Permission
//   // it("fails if invalid taker/maker signature", async () => {})
//   // it("fails if invalid taker/maker has no trade permission", async () => {})

//   // // Trade
//   // it("fails if no order match", async () => {})
//   // it("fails if inconsistent number of legs", async () => {})
//   // it("fails if self-trade", async () => {})
//   // it("fails if taker/maker is fee position", async () => {})
//   // it("fails if full order is replayed", async () => {})
//   // it("fails if partial order exceed the remaining quantity", async () => {})

//   // // Order validation
//   // it("fails if market order and limit/oco price != 0", async () => {})
//   // it("fails if not market order and limit/oco price == 0", async () => {})
//   // it("fails if invalid timeInForce and postOnly combo", async () => {})
//   // it("fails if legs are not sorted by derivative ID", async () => {})
//   // it("fails if too many legs", async () => {})

//   // // After trade
//   // it("fails if invalid total value", async () => {})
// })

// function getOrderWithSig(w: Wallet, o: OrderNoSignature): Order {
//   return { ...o, signature: genOrderSig(w, o) }
// }
