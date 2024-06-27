import { BigNumber, BigNumberish } from "ethers"

export enum MarginType {
  UNSPECIFIED,
  ISOLATED,
  SIMPLE_CROSS_MARGIN,
  PORTFOLIO_CROSS_MARGIN,
}

export enum Currency {
  UNSPECIFIED,
  USDC,
  USDT,
  ETH,
  BTC,
}

export enum Instrument {
  UNSPECIFIED,
  PERPS,
  FUTURES,
  CALL,
  PUT,
}

export enum AccountRecoveryType {
  UNSPECIFIED,
  GUARDIAN,
  SUB_ACCOUNT_SIGNERS,
}

export const AccPerm = {
  None: 0,
  Admin: 1 << 1,
  InternalTransfer: 1 << 2,
  ExternalTransfer: 1 << 3,
  Withdrawal: 1 << 4,
}

export const SubPerm = {
  None: 0,
  Admin: 1 << 1,
  Transfer: 1 << 2,
  Trade: 1 << 3,
}

export const ConfigID = {
  UNSPECIFIED: 0,
  SM_FUTURES_INITIAL_MARGIN: 1,
  SM_FUTURES_MAINTENANCE_MARGIN: 2,
  SM_FUTURES_VARIABLE_MARGIN: 3,
  SM_OPTIONS_INITIAL_MARGIN_HIGH: 4,
  SM_OPTIONS_INITIAL_MARGIN_LOW: 5,
  SM_OPTIONS_MAINTENANCE_MARGIN_HIGH: 6,
  SM_OPTIONS_MAINTENANCE_MARGIN_LOW: 7,
  SM_OPTIONS_VARIABLE_MARGIN: 8,
  PM_SPOT_MOVE: 9,
  PM_VOL_MOVE_UP: 10,
  PM_VOL_MOVE_DOWN: 11,
  PM_SPOT_MOVE_EXTREME: 12,
  PM_EXTREME_MOVE_DISCOUNT: 13,
  PM_SHORT_TERM_VEGA_POWER: 14,
  PM_LONG_TERM_VEGA_POWER: 15,
  PM_INITIAL_MARGIN_FACTOR: 16,
  PM_NET_SHORT_OPTION_MINIMUM: 17,
  ADMIN_RECOVERY_ADDRESS: 18,
  FEE_SUB_ACCOUNT_ID: 19,
}

export const NumConfig = Object.keys(ConfigID).length

export type ScheduleConfigEntry = {
  lockEndTime: number
  exists: number
  value: string
}

export interface ZKSyncMysteryBoxDefiTaskSignature {
  signer: string
  nonce: number
  message: string
}

export interface OrderNoSignature {
  subAccountID: string // The subaccount initiating the order
  isMarket: boolean // If the order is a market order
  timeInForce: TimeInForce // Four supported types of orders
  takerFeePercentageCap: number // The taker fee percentage cap signed by the order
  makerFeePercentageCap: number // Same as TakerFeePercentageCap, but for the maker fee. Negative for maker rebates
  postOnly: boolean // If True, Order must be a maker order
  reduceOnly: boolean // If True, Order must reduce the position size, or be cancelled
  legs: OrderLeg[] // The legs present in this order
  nonce: number
}

export interface Order extends OrderNoSignature {
  signature: Signature
}

export interface Signature {
  signer: string
  expiration: BigInt // expiration timestamp in nano seconds
  r: Buffer
  s: Buffer
  v: number
  nonce: number
}

export interface OrderLeg {
  assetID: string // uint256
  contractSize: number
  limitPrice: number
  ocoLimitPrice: number
  isBuyingContract: boolean
}

export enum TimeInForce {
  UNSPECIFIED,
  GOOD_TILL_TIME,
  ALL_OR_NONE,
  IMMEDIATE_OR_CANCEL,
  FILL_OR_KILL,
}

export interface OrderMatch {
  makerOrder: Order
  numContractsMatched: number[]
  takerFeePercentageCharged: number
  makerFeePercentageCharged: number
}

export interface Trade {
  takerOrder: Order
  makerOrders: OrderMatch[]
}

export interface PriceEntrySig {
  sid: BigNumberish
  v: BigNumberish
}

export interface PriceEntry {
  assetID: string
  value: BigNumberish
}
