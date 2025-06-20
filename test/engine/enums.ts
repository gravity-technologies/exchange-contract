export const CurrencyToEnum: { [cur: string]: number } = {
  UNSPECIFIED: 0,
  USD: 1,
  USDC: 2,
  USDT: 3,
  ETH: 4,
  BTC: 5,
  SOL: 6,
  ARB: 7,
  BNB: 8,
  ZK: 9,
  POL: 10,
  OP: 11,
  ATOM: 12,
  KPEPE: 13,
  TON: 14,
  XRP: 15,
  XLM: 16,
  WLD: 17,
  WIF: 18,
  VIRTUAL: 19,
  TRUMP: 20,
  SUI: 21,
  KSHIB: 22,
  POPCAT: 23,
  PENGU: 24,
  LINK: 25,
  KBONK: 26,
  JUP: 27,
  FARTCOIN: 28,
  ENA: 29,
  DOGE: 30,
  AIXBT: 31,
  AI16Z: 32,
  ADA: 33,
  AAVE: 34,
  BERA: 35,
  VINE: 36,
  PENDLE: 37,
  UXLINK: 38,
  KAITO: 39,
  IP: 40,
}

// CurrencyIDToName provides a reverse lookup from currency ID to currency name
export const CurrencyIDToName: { [id: number]: string } = Object.fromEntries(
  Object.entries(CurrencyToEnum).map(([name, id]) => [id, name])
)

export const MarginTypeToEnum: { [cur: string]: number } = {
  SIMPLE_CROSS_MARGIN: 2,
  PORTFOLIO_CROSS_MARGIN: 3,
}

export const KindToEnum: { [kind: string]: number } = {
  UNSPECIFIED: 0,
  PERPETUAL: 1,
  FUTURE: 2,
  CALL: 3,
  PUT: 4,
  SPOT: 5,
  SETTLEMENT: 6,
  RATE: 7,
}

export const ConfigIDToEnum: { [config: string]: number } = {
  UNSPECIFIED: 0,
  DEPRECATED_1: 1,
  ORACLE_ADDRESS: 2,
  CONFIG_ADDRESS: 3,
  MARKET_DATA_ADDRESS: 4,
  ADMIN_FEE_SUB_ACCOUNT_ID: 5,
  INSURANCE_FUND_SUB_ACCOUNT_ID: 6,
  FUNDING_RATE_HIGH: 7,
  FUNDING_RATE_LOW: 8,
  FUTURES_MAKER_FEE_MINIMUM: 9,
  FUTURES_TAKER_FEE_MINIMUM: 10,
  OPTIONS_MAKER_FEE_MINIMUM: 11,
  OPTIONS_TAKER_FEE_MINIMUM: 12,
  ERC_20_ADDRESSES: 13,
  L_2_SHARED_BRIDGE_ADDRESS: 14,
  SIMPLE_CROSS_FUTURES_INITIAL_MARGIN: 15,
  WITHDRAWAL_FEE: 16,
  BRIDGING_PARTNER_ADDRESSES: 17
};

export const VaultStatusToEnum: { [status: string]: number } = {
  UNSPECIFIED: 0,
  ACTIVE: 1,
  DELISTED: 2,
  CLOSED: 3
}
