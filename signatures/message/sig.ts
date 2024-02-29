import * as Type from "./type"

// Account
export function GetCreateAccount(accountID: string, nonce: number) {
  return {
    ...Type.CreateAccount,
    message: {
      accountID,
      nonce,
    },
  }
}

export function GetSetAccountMultiSigThreshold(accountID: string, multiSigThreshold: number, nonce: number) {
  return {
    ...Type.SetAccountMultiSigThreshold,
    message: {
      accountID,
      multiSigThreshold,
      nonce,
    },
  }
}

export function GetAddAccountSigner(accountID: string, signer: string, permissions: number, nonce: number) {
  return {
    ...Type.AddAccountSigner,
    message: {
      accountID,
      signer,
      permissions,
      nonce,
    },
  }
}

export function GetSetAccountSignerPermission(accountID: string, signer: string, permissions: number, nonce: number) {
  return {
    ...Type.SetAccountSignerPermissions,
    message: {
      accountID,
      signer,
      permissions,
      nonce,
    },
  }
}

export function GetRemoveAccountSigner(accountID: string, signer: string, nonce: number) {
  return {
    ...Type.RemoveAccountSigner,
    message: {
      accountID,
      signer,
      nonce,
    },
  }
}

export function GetAddWithdrawalAddress(accountID: string, withdrawalAddress: string, nonce: number) {
  return {
    ...Type.AddWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
    },
  }
}

export function GetRemoveWithdrawalAddress(accountID: string, withdrawalAddress: string, nonce: number) {
  return {
    ...Type.RemoveWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
    },
  }
}

export function GetAddTransferSubAccount(accountID: string, transferSubAccount: string, nonce: number) {
  return {
    ...Type.AddTransferSubAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
    },
  }
}

export function GetRemoveTransferSubAccount(accountID: string, transferSubAccount: string, nonce: number) {
  return {
    ...Type.RemoveTransferSubAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
    },
  }
}

// SubAccount
export function GetCreateSubAccount(
  accountID: string,
  subAccountID: number,
  quoteCurrency: number,
  marginType: number,
  nonce: number
) {
  return {
    ...Type.CreateSubAccount,
    message: {
      accountID,
      subAccountID,
      quoteCurrency,
      marginType,
      nonce,
    },
  }
}

export function GetSetSubAccountMarginType(subAccountID: number, marginType: number, nonce: number) {
  return {
    ...Type.SetSubAccountMarginType,
    message: {
      subAccountID,
      marginType,
      nonce,
    },
  }
}

export function GetAddSubAccountSigner(subAccountID: number, signer: string, permissions: number, nonce: number) {
  return {
    ...Type.AddSubAccountSigner,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
    },
  }
}

export function GetSetSubAccountSignerPermissions(
  subAccountID: number,
  signer: string,
  permissions: number,
  nonce: number
) {
  return {
    ...Type.SetSubAccountSignerPermissions,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
    },
  }
}

export function GetRemoveSubAccountSigner(subAccountID: number, signer: string, nonce: number) {
  return {
    ...Type.RemoveSubAccountSigner,
    message: {
      subAccountID,
      signer,
      nonce,
    },
  }
}

// Config
export function GetScheduleConfig(key: number, subKey: string, value: string, nonce: number) {
  return {
    ...Type.ScheduleConfig,
    message: {
      key,
      subKey,
      value,
      nonce,
    },
  }
}

export function GetSetConfig(key: number, subKey: string, value: string, nonce: number) {
  return {
    ...Type.SetConfig,
    message: {
      key,
      subKey,
      value,
      nonce,
    },
  }
}

// Session
export function GetAddSessionKey(sessionKey: string, keyExpiry: number) {
  return {
    ...Type.AddSessionKey,
    message: {
      sessionKey,
      keyExpiry,
    },
  }
}

// Transfer
export function GetDeposit(
  fromEthAddress: string,
  toAccount: string,
  tokenCurrency: number,
  numTokens: number,
  nonce: number
) {
  return {
    ...Type.Deposit,
    message: {
      fromEthAddress,
      toAccount,
      tokenCurrency,
      numTokens,
      nonce,
    },
  }
}

export function GetWithdrawal(
  fromAccount: string,
  toEthAddress: string,
  tokenCurrency: number,
  numTokens: number,
  nonce: number
) {
  return {
    ...Type.Withdrawal,
    message: {
      fromAccount,
      toEthAddress,
      tokenCurrency,
      numTokens,
      nonce,
    },
  }
}

export function GetTransfer(
  fromAccount: string,
  fromSubAccount: number,
  toAccount: string,
  toSubAccount: number,
  tokenCurrency: number,
  numTokens: number,
  nonce: number
) {
  return {
    ...Type.Transfer,
    message: {
      fromAccount,
      fromSubAccount,
      toAccount,
      toSubAccount,
      tokenCurrency,
      numTokens,
      nonce,
    },
  }
}

export type Order = {
  subAccountID: string
  isMarket: boolean
  timeInForce: number
  limitPrice: string
  ocoLimitPrice: string
  takerFeePercentageCap: string
  makerFeePercentageCap: string
  postOnly: boolean
  reduceOnly: boolean
  isPayingBaseCurrency: boolean
  legs: OrderLeg[]
  nonce: number
}

export type OrderLeg = {
  derivative: string
  contractSize: string
  limitPrice: string
  ocoLimitPrice: string
  isBuyingContract: boolean
}

// Trade
export function GetOrder(order: Order) {
  return {
    ...Type.Order,
    message: order,
  }
}
