const KeyMirror = require("keymirror")
const { EIP712Domain, domain } = require("./common.js")

const Primary = KeyMirror({
  // Account
  AddAccountAdminPayload: 0,
  AddTransferSubAccountPayload: 0,
  AddWithdrawalAddressPayload: 0,
  CreateSubAccountPayload: 0,
  RemoveAccountAdminPayload: 0,
  RemoveTransferSubAccountPayload: 0,
  RemoveWithdrawalAddressPayload: 0,
  SetAccountMultiSigThresholdPayload: 0,

  // Account Recovery
  AddAccountGuardianPayload: 0,
  RemoveAccountGuardianPayload: 0,
  RecoverAccountAdminPayload: 0,

  // SubAccount
  AddSubAccountSignerPayload: 0,
  RemoveSubAccountSignerPayload: 0,
  SetSubAccountMarginTypePayload: 0,
  SetSubAccountSignerPermissionsPayload: 0,

  // Config
  ScheduleConfigPayload: 0,
  SetConfigPayload: 0,

  // Session Key
  AddSessionKeyPayload: 0,

  // Transfer
  DepositPayload: 0,
  TransferPayload: 0,
  WithdrawalPayload: 0,

  // Trade
  TradePayload: 0,
})

// -------------- Account --------------
const CreateSubAccountPayload = {
  primaryType: Primary.CreateSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.CreateSubAccountPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "subAccountID", type: "address" },
      { name: "quoteCurrency", type: "uint8" },
      { name: "marginType", type: "uint8" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const SetAccountMultiSigThresholdPayload = {
  primaryType: Primary.SetAccountMultiSigThresholdPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetAccountMultiSigThresholdPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "multiSigThreshold", type: "uint8" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const AddAccountAdminPayload = {
  primaryType: Primary.AddAccountAdminPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddAccountAdminPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RemoveAccountAdminPayload = {
  primaryType: Primary.RemoveAccountAdminPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveAccountAdminPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const AddWithdrawalAddressPayload = {
  primaryType: Primary.AddWithdrawalAddressPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddWithdrawalAddressPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "withdrawalAddress", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RemoveWithdrawalAddressPayload = {
  primaryType: Primary.RemoveWithdrawalAddressPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveWithdrawalAddressPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "withdrawalAddress", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const AddTransferSubAccountPayload = {
  primaryType: Primary.AddTransferSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddTransferSubAccountPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "transferSubAccount", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RemoveTransferSubAccountPayload = {
  primaryType: Primary.RemoveTransferSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveTransferSubAccountPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "transferSubAccount", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

// -------------- SubAccount --------------
const SetSubAccountMarginTypePayload = {
  primaryType: Primary.SetSubAccountMarginTypePayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetSubAccountMarginTypePayload]: [
      { name: "subAccountID", type: "address" },
      { name: "marginType", type: "uint8" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const AddSubAccountSignerPayload = {
  primaryType: Primary.AddSubAccountSignerPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddSubAccountSignerPayload]: [
      { name: "subAccountID", type: "address" },
      { name: "signer", type: "address" },
      { name: "permissions", type: "uint16" },
      { name: "nonce", type: "uint32" },
    ],
  },
}
const SetSubAccountSignerPermissionsPayload = {
  primaryType: Primary.SetSubAccountSignerPermissionsPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetSubAccountSignerPermissionsPayload]: [
      { name: "subAccountID", type: "address" },
      { name: "signer", type: "address" },
      { name: "permissions", type: "uint64" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RemoveSubAccountSignerPayload = {
  primaryType: Primary.RemoveSubAccountSignerPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveSubAccountSignerPayload]: [
      { name: "subAccountID", type: "address" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

// Account Recovery
const AddAccountGuardianPayload = {
  primaryType: Primary.AddAccountGuardianPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddAccountGuardianPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RemoveAccountGuardianPayload = {
  primaryType: Primary.RemoveAccountGuardianPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveAccountGuardianPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "signer", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const RecoverAccountAdminPayload = {
  primaryType: Primary.RecoverAccountAdminPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RecoverAccountAdminPayload]: [
      { name: "accountID", type: "uint32" },
      { name: "recoveryType", type: "uint8" },
      { name: "oldAdmin", type: "address" },
      { name: "recoveryAdmin", type: "address" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

// Config
const ScheduleConfigPayload = {
  primaryType: Primary.ScheduleConfigPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.ScheduleConfigPayload]: [
      { name: "key", type: "uint8" },
      { name: "value", type: "bytes32" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const SetConfigPayload = {
  primaryType: Primary.SetConfigPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetConfigPayload]: [
      { name: "key", type: "uint8" },
      { name: "value", type: "bytes32" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

// -------------- Session Keys --------------
const AddSessionKeyPayload = {
  primaryType: Primary.AddSessionKeyPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddSessionKeyPayload]: [
      { name: "sessionKey", type: "address" },
      { name: "keyExpiry", type: "uint64" },
    ],
  },
}

// -------------- Transfer --------------
const DepositPayload = {
  primaryType: Primary.DepositPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.DepositPayload]: [
      { name: "fromEthAddress", type: "address" },
      { name: "toSubAccount", type: "address" },
      { name: "numTokens", type: "uint64" },
      { name: "nonce", type: "uint32" },
    ],
  },
}
const WithdrawalPayload = {
  primaryType: Primary.WithdrawalPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.WithdrawalPayload]: [
      { name: "fromSubAccount", type: "address" },
      { name: "toEthAddress", type: "address" },
      { name: "numTokens", type: "uint64" },
      { name: "nonce", type: "uint32" },
    ],
  },
}
const TransferPayload = {
  primaryType: Primary.TransferPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.TransferPayload]: [
      { name: "fromSubAccount", type: "address" },
      { name: "toSubAccount", type: "address" },
      { name: "numTokens", type: "uint64" },
      { name: "nonce", type: "uint32" },
    ],
  },
}

const TradePayload = {
  primaryType: Primary.TransferPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.TradePayload]: [
      { name: "trade", type: "Trade" },
      { name: "nonce", type: "uint32" },
    ],
    Trade: [
      { name: "takerOrder", type: "Order" },
      { name: "makerOrders", type: "OrderMatch[]" },
    ],
    Order: [
      { name: "subAccountID", type: "uint32" },
      { name: "isMarket", type: "bool" },
      { name: "timeInForce", type: "uint8" },
      { name: "limitPrice", type: "uint64" },
      { name: "takerFeePercentageCap", type: "uint32" },
      { name: "makerFeePercentageCap", type: "uint32" },
      { name: "postOnly", type: "bool" },
      { name: "reduceOnly", type: "bool" },
      { name: "isPayingBaseCurrency", type: "bool" },
      { name: "legs", type: "OrderLeg[]" },
      { name: "signature", type: "Signature" },
    ],
    OrderLeg: [
      { name: "derivative", type: "uint128" },
      { name: "contractSize", type: "uint64" },
      { name: "limitPrice", type: "uint64" },
      { name: "ocoLimitPrice", type: "uint64" },
      { name: "isBuyingContract", type: "bool" },
    ],
    OrderMatch: [
      { name: "makerOrder", type: "Order" },
      { name: "numContractsMatched", type: "uint64[]" },
      { name: "takerFeePercentageCharged", type: "uint32" },
      { name: "makerFeePercentageCharged", type: "uint32" },
    ],
    Signature: [
      { name: "signer", type: "address" },
      { name: "r", type: "uint256" },
      { name: "s", type: "uint256" },
      { name: "v", type: "uint8" },
      { name: "expiration", type: "int64" },
    ],
  },
}

module.exports = {
  // Account
  CreateSubAccountPayload,
  AddAccountAdminPayload,
  AddTransferSubAccountPayload,
  AddWithdrawalAddressPayload,
  CreateSubAccountPayload,
  RemoveAccountAdminPayload,
  RemoveTransferSubAccountPayload,
  RemoveWithdrawalAddressPayload,
  SetAccountMultiSigThresholdPayload,

  // Account Recovery
  AddAccountGuardianPayload,
  RemoveAccountGuardianPayload,
  RecoverAccountAdminPayload,

  // SubAccount
  AddSubAccountSignerPayload,
  RemoveSubAccountSignerPayload,
  SetSubAccountMarginTypePayload,
  SetSubAccountSignerPermissionsPayload,

  // Config
  ScheduleConfigPayload,
  SetConfigPayload,

  // Session
  AddSessionKeyPayload,

  // Transfer
  DepositPayload,
  TransferPayload,
  WithdrawalPayload,

  // Trade
  TradePayload,
}
