enum TransactionType {
  unspecified = 0,
  unspecified1 = 1,
  unspecified2 = 2,
  unspecified3 = 3,
  createAccount = 4,
  createSubAccount = 5,
  setAccountMultiSigThreshold = 6,
  addAccountSigner = 7,
  setAccountSignerPermissions = 8,
  removeAccountSigner = 9,
  addWithdrawalAddress = 10,
  removeWithdrawalAddress = 11,
  addTransferAccount = 12,
  removeTransferAccount = 13,
  addAccountGuardian = 14,
  removeAccountGuardian = 15,
  recoverAccountAdmin = 16,
  setSubAccountMarginType = 17,
  addSubAccountSigner = 18,
  setSubAccountSignerPermissions = 19,
  removeSubAccountSigner = 20,
  addSessionKey = 21,
  removeSessionKey = 22,
  deposit = 23,
  withdrawal = 24,
  transfer = 25,
  markPriceTick = 26,
  settlementPriceTick = 27,
  fundingTick = 28,
  interestRateTick = 29,
  depositIntoSafetyModule = 30,
  withdrawFromSafetyModule = 31,
  scheduleConfig = 32,
  setConfig = 33,
  deleverage = 34,
  liquidate = 35,
  trade = 36,
  testnetOnlyRemoveAccount = 37,
}

function TransactionTypeToString(value: TransactionType): string {
  switch (value) {
    case TransactionType.unspecified:
      return "unspecified"
    case TransactionType.unspecified1:
      return "unspecified1"
    case TransactionType.unspecified2:
      return "unspecified2"
    case TransactionType.unspecified3:
      return "unspecified3"
    case TransactionType.createAccount:
      return "createAccount"
    case TransactionType.createSubAccount:
      return "createSubAccount"
    case TransactionType.setAccountMultiSigThreshold:
      return "setAccountMultiSigThreshold"
    case TransactionType.addAccountSigner:
      return "addAccountSigner"
    case TransactionType.setAccountSignerPermissions:
      return "setAccountSignerPermissions"
    case TransactionType.removeAccountSigner:
      return "removeAccountSigner"
    case TransactionType.addWithdrawalAddress:
      return "addWithdrawalAddress"
    case TransactionType.removeWithdrawalAddress:
      return "removeWithdrawalAddress"
    case TransactionType.addTransferAccount:
      return "addTransferAccount"
    case TransactionType.removeTransferAccount:
      return "removeTransferAccount"
    case TransactionType.addAccountGuardian:
      return "addAccountGuardian"
    case TransactionType.removeAccountGuardian:
      return "removeAccountGuardian"
    case TransactionType.recoverAccountAdmin:
      return "recoverAccountAdmin"
    case TransactionType.setSubAccountMarginType:
      return "setSubAccountMarginType"
    case TransactionType.addSubAccountSigner:
      return "addSubAccountSigner"
    case TransactionType.setSubAccountSignerPermissions:
      return "setSubAccountSignerPermissions"
    case TransactionType.removeSubAccountSigner:
      return "removeSubAccountSigner"
    case TransactionType.addSessionKey:
      return "addSessionKey"
    case TransactionType.removeSessionKey:
      return "removeSessionKey"
    case TransactionType.deposit:
      return "deposit"
    case TransactionType.withdrawal:
      return "withdrawal"
    case TransactionType.transfer:
      return "transfer"
    case TransactionType.markPriceTick:
      return "markPriceTick"
    case TransactionType.settlementPriceTick:
      return "settlementPriceTick"
    case TransactionType.fundingTick:
      return "fundingTick"
    case TransactionType.interestRateTick:
      return "interestRateTick"
    case TransactionType.depositIntoSafetyModule:
      return "depositIntoSafetyModule"
    case TransactionType.withdrawFromSafetyModule:
      return "withdrawFromSafetyModule"
    case TransactionType.scheduleConfig:
      return "scheduleConfig"
    case TransactionType.setConfig:
      return "setConfig"
    case TransactionType.deleverage:
      return "deleverage"
    case TransactionType.liquidate:
      return "liquidate"
    case TransactionType.trade:
      return "trade"
    case TransactionType.testnetOnlyRemoveAccount:
      return "testnetOnlyRemoveAccount"
    default:
      return ""
  }
}
