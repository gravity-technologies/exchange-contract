function keyMirror(originObj: object) {
  const obj: any = {}
  for (const key in originObj) {
    if (originObj.hasOwnProperty(key)) obj[key] = key
  }
  return obj
}

export const EIP712Domain = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
]

// IMPORTANT Set the chainID here
const localEraNodeChainID = 271

export const domain = {
  name: "GRVT Exchange",
  version: "0",
  chainId: localEraNodeChainID,
}

// ZkSync Mystery Box task
export const PrimaryType = keyMirror({
  // Account
  CreateAccount: 0,
  AddAccountSigner: 0,
  RemoveAccountSigner: 0,
  AddTransferAccount: 0,
  RemoveTransferAccount: 0,
  AddWithdrawalAddress: 0,
  RemoveWithdrawalAddress: 0,
  SetAccountMultiSigThreshold: 0,

  // SubAccount
  CreateSubAccount: 0,
  AddSubAccountSigner: 0,
  RemoveSubAccountSigner: 0,
  SetSubAccountMarginType: 0,
  SetSubAccountSignerPermissions: 0,

  // Wallet Recovery
  AddRecoveryAddress: 0,
  RemoveRecoveryAddress: 0,
  RecoverAddress: 0,

  // Config
  ScheduleConfig: 0,
  SetConfig: 0,

  // Session Key
  AddSessionKey: 0,

  // Transfer
  Deposit: 0,
  Transfer: 0,
  Withdrawal: 0,

  // Trade
  Order: 0,

  // Oracle
  Data: 0,

  // Liquidation
  LiquidationOrder: 0,
})

// -------------- Account --------------
export const CreateAccount = {
  primaryType: PrimaryType.CreateAccount,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.CreateAccount]: [
      { name: "accountID", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const SetAccountMultiSigThreshold = {
  primaryType: PrimaryType.SetAccountMultiSigThreshold,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.SetAccountMultiSigThreshold]: [
      { name: "accountID", type: "address" },
      { name: "multiSigThreshold", type: "uint8" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const AddAccountSigner = {
  primaryType: PrimaryType.AddAccountSigner,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddAccountSigner]: [
      { name: "accountID", type: "address" },
      { name: "signer", type: "address" },
      { name: "permissions", type: "uint64" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RemoveAccountSigner = {
  primaryType: PrimaryType.RemoveAccountSigner,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RemoveAccountSigner]: [
      { name: "accountID", type: "address" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const AddWithdrawalAddress = {
  primaryType: PrimaryType.AddWithdrawalAddress,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddWithdrawalAddress]: [
      { name: "accountID", type: "address" },
      { name: "withdrawalAddress", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RemoveWithdrawalAddress = {
  primaryType: PrimaryType.RemoveWithdrawalAddress,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RemoveWithdrawalAddress]: [
      { name: "accountID", type: "address" },
      { name: "withdrawalAddress", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const AddTransferAccount = {
  primaryType: PrimaryType.AddTransferAccount,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddTransferAccount]: [
      { name: "accountID", type: "address" },
      { name: "transferAccountID", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RemoveTransferAccount = {
  primaryType: PrimaryType.RemoveTransferAccount,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RemoveTransferAccount]: [
      { name: "accountID", type: "address" },
      { name: "transferAccountID", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

// -------------- SubAccount --------------
export const CreateSubAccount = {
  primaryType: PrimaryType.CreateSubAccount,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.CreateSubAccount]: [
      { name: "accountID", type: "address" },
      { name: "subAccountID", type: "uint64" },
      { name: "quoteCurrency", type: "uint8" },
      { name: "marginType", type: "uint8" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const SetSubAccountMarginType = {
  primaryType: PrimaryType.SetSubAccountMarginType,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.SetSubAccountMarginType]: [
      { name: "subAccountID", type: "uint64" },
      { name: "marginType", type: "uint8" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const AddSubAccountSigner = {
  primaryType: PrimaryType.AddSubAccountSigner,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddSubAccountSigner]: [
      { name: "subAccountID", type: "uint64" },
      { name: "signer", type: "address" },
      { name: "permissions", type: "uint64" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}
export const SetSubAccountSignerPermissions = {
  primaryType: PrimaryType.SetSubAccountSignerPermissions,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.SetSubAccountSignerPermissions]: [
      { name: "subAccountID", type: "uint64" },
      { name: "signer", type: "address" },
      { name: "permissions", type: "uint64" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RemoveSubAccountSigner = {
  primaryType: PrimaryType.RemoveSubAccountSigner,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RemoveSubAccountSigner]: [
      { name: "subAccountID", type: "uint64" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

// Wallet Recovery
export const AddRecoveryAddress = {
  primaryType: PrimaryType.AddRecoveryAddress,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddRecoveryAddress]: [
      { name: "accountID", type: "address" },
      { name: "recoverySigner", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RemoveRecoveryAddress = {
  primaryType: PrimaryType.RemoveRecoveryAddress,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RemoveRecoveryAddress]: [
      { name: "accountID", type: "address" },
      { name: "recoverySigner", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const RecoverAddress = {
  primaryType: PrimaryType.RecoverAddress,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.RecoverAddress]: [
      { name: "accountID", type: "address" },
      { name: "oldSigner", type: "address" },
      { name: "newSigner", type: "address" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

// Config
export const ScheduleConfig = {
  primaryType: PrimaryType.ScheduleConfig,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.ScheduleConfig]: [
      { name: "key", type: "uint8" },
      { name: "subKey", type: "bytes32" },
      { name: "value", type: "bytes32" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const SetConfig = {
  primaryType: PrimaryType.SetConfig,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.SetConfig]: [
      { name: "key", type: "uint8" },
      { name: "subKey", type: "bytes32" },
      { name: "value", type: "bytes32" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

// -------------- Session Keys --------------
export const AddSessionKey = {
  primaryType: PrimaryType.AddSessionKey,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.AddSessionKey]: [
      { name: "sessionKey", type: "address" },
      { name: "keyExpiry", type: "int64" },
    ],
  },
}

// -------------- Transfer --------------
export const Withdrawal = {
  primaryType: PrimaryType.Withdrawal,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.Withdrawal]: [
      { name: "fromAccount", type: "address" },
      { name: "toEthAddress", type: "address" },
      { name: "tokenCurrency", type: "uint8" },
      { name: "numTokens", type: "uint64" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}
export const Transfer = {
  primaryType: PrimaryType.Transfer,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.Transfer]: [
      { name: "fromAccount", type: "address" },
      { name: "fromSubAccount", type: "uint64" },
      { name: "toAccount", type: "address" },
      { name: "toSubAccount", type: "uint64" },
      { name: "tokenCurrency", type: "uint8" },
      { name: "numTokens", type: "uint64" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
  },
}

export const OrderSchema = {
  primaryType: PrimaryType.Order,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.Order]: [
      { name: "subAccountID", type: "uint64" },
      { name: "isMarket", type: "bool" },
      { name: "timeInForce", type: "uint8" },
      { name: "takerFeePercentageCap", type: "int32" },
      { name: "makerFeePercentageCap", type: "int32" },
      { name: "postOnly", type: "bool" },
      { name: "reduceOnly", type: "bool" },
      { name: "legs", type: "OrderLeg[]" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
    OrderLeg: [
      { name: "assetID", type: "uint256" },
      { name: "contractSize", type: "uint64" },
      { name: "limitPrice", type: "uint64" },
      { name: "ocoLimitPrice", type: "uint64" },
      { name: "isBuyingContract", type: "bool" },
    ],
  },
}

// -------------- Oracle --------------
export const OracleData = {
  primaryType: PrimaryType.Data,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.Data]: [
      { name: "values", type: "Values[]" },
      { name: "timestamp", type: "int256" },
    ],
    Values: [
      { name: "sid", type: "int256" },
      { name: "v", type: "int256" },
    ],
  },
}

// -------------- Liquidation --------------
export const LiquidationOrderSchema = {
  primaryType: PrimaryType.LiquidationOrder,
  domain,
  types: {
    EIP712Domain,
    [PrimaryType.LiquidationOrder]: [
      { name: "subAccountID", type: "uint64" },
      { name: "legs", type: "OrderLeg[]" },
      { name: "nonce", type: "uint32" },
      { name: "expiration", type: "int64" },
    ],
    OrderLeg: [
      { name: "assetID", type: "uint256" },
      { name: "contractSize", type: "uint64" },
      { name: "limitPrice", type: "uint64" },
      { name: "ocoLimitPrice", type: "uint64" },
      { name: "isBuyingContract", type: "bool" },
    ],
  },
}
