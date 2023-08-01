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

export const Perm = {
  None: 0,
  Admin: 1,
  Deposit: 1 << 1,
  Withdrawal: 1 << 2,
  Transfer: 1 << 3,
  Trade: 1 << 4,
  AddSigner: 1 << 5,
  RemoveSigner: 1 << 6,
  UpdateSignerPermission: 1 << 7,
  ChangeMarginType: 1 << 8,
}
