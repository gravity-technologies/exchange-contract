import { Wallet, utils } from "ethers"
import * as Type from "./schema"
import { SignTypedDataVersion, signTypedData } from "@metamask/eth-sig-util"

// Account
export function GetCreateAccountHash(accountID: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.CreateAccount,
    message: {
      accountID,
      nonce,
      expiration,
    },
  }
}

export function GetSetAccountMultiSigThresholdHash(accountID: string, multiSigThreshold: number, nonce: number, expiration: BigInt) {
  return {
    ...Type.SetAccountMultiSigThreshold,
    message: {
      accountID,
      multiSigThreshold,
      nonce,
      expiration,
    },
  }
}

export function GetAddAccountSignerHash(accountID: string, signer: string, permissions: number, nonce: number, expiration: BigInt) {
  return {
    ...Type.AddAccountSigner,
    message: {
      accountID,
      signer,
      permissions,
      nonce,
      expiration,
    },
  }
}

export function GetRemoveAccountSignerHash(accountID: string, signer: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.RemoveAccountSigner,
    message: {
      accountID,
      signer,
      nonce,
      expiration,
    },
  }
}

export function GetAddWithdrawalAddressHash(accountID: string, withdrawalAddress: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.AddWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
      expiration,
    },
  }
}

export function GetRemoveWithdrawalAddressHash(accountID: string, withdrawalAddress: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.RemoveWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
      expiration,
    },
  }
}

export function GetAddTransferAccountHash(accountID: string, transferSubAccount: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.AddTransferAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
      expiration,
    },
  }
}

export function GetRemoveTransferAccountHash(accountID: string, transferSubAccount: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.RemoveTransferAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
      expiration,
    },
  }
}

export function GetRecoverAddressHash(accountID: string, oldSigner: string, newSigner: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.RecoverAddress,
    message: {
      accountID,
      oldSigner,
      newSigner,
      nonce,
      expiration,
    },
  }
}

// SubAccount
export function GetCreateSubAccountHash(
  accountID: string,
  subAccountID: number,
  quoteCurrency: number,
  marginType: number,
  nonce: number,
  expiration: BigInt
) {
  return {
    ...Type.CreateSubAccount,
    message: {
      accountID,
      subAccountID,
      quoteCurrency,
      marginType,
      nonce,
      expiration,
    },
  }
}

export function GetSetSubAccountMarginTypeHash(subAccountID: number, marginType: number, nonce: number, expiration: BigInt) {
  return {
    ...Type.SetSubAccountMarginType,
    message: {
      subAccountID,
      marginType,
      nonce,
      expiration,
    },
  }
}

export function GetAddSubAccountSignerHash(subAccountID: number, signer: string, permissions: number, nonce: number, expiration: BigInt) {
  return {
    ...Type.AddSubAccountSigner,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
      expiration,
    },
  }
}

export function GetSetSubAccountSignerPermissionsHash(
  subAccountID: number,
  signer: string,
  permissions: number,
  nonce: number,
  expiration: BigInt
) {
  return {
    ...Type.SetSubAccountSignerPermissions,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
      expiration,
    },
  }
}

export function GetRemoveSubAccountSignerHash(subAccountID: number, signer: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.RemoveSubAccountSigner,
    message: {
      subAccountID,
      signer,
      nonce,
      expiration,
    },
  }
}

// Config
export function GetScheduleConfigHash(key: number, subKey: string, value: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.ScheduleConfig,
    message: {
      key,
      subKey,
      value,
      nonce,
      expiration,
    },
  }
}

export function GetSetConfigHash(key: number, subKey: string, value: string, nonce: number, expiration: BigInt) {
  return {
    ...Type.SetConfig,
    message: {
      key,
      subKey,
      value,
      nonce,
      expiration,
    },
  }
}

// Session
export function GetAddSessionKeyHash(sessionKey: string, keyExpiry: number, expiration: BigInt) {
  return {
    ...Type.AddSessionKey,
    message: {
      sessionKey,
      keyExpiry,
      expiration,
    },
  }
}

// Transfer
export function GetWithdrawalHash(
  fromAccount: string,
  toEthAddress: string,
  tokenCurrency: number,
  numTokens: number,
  nonce: number,
  expiration: BigInt
) {
  return {
    ...Type.Withdrawal,
    message: {
      fromAccount,
      toEthAddress,
      tokenCurrency,
      numTokens,
      nonce,
      expiration,
    },
  }
}

export function GetTransferHash(
  fromAccount: string,
  fromSubAccount: number,
  toAccount: string,
  toSubAccount: number,
  tokenCurrency: number,
  numTokens: number,
  nonce: number,
  expiration: BigInt
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
      expiration,
    },
  }
}

export type Order = {
  subAccountID: string
  isMarket: boolean
  timeInForce: number
  limitPrice: string
  takerFeePercentageCap: string
  makerFeePercentageCap: string
  postOnly: boolean
  reduceOnly: boolean
  isPayingBaseCurrency: boolean
  legs: OrderLeg[]
  nonce: number
}

export type LiquidationOrder = {
  subAccountID: string
  legs: OrderLeg[]
  nonce: number
  expiration: BigInt
}

export type OrderLeg = {
  derivative: string
  contractSize: string
  limitPrice: string
  isBuyingContract: boolean
}

// Trade
export function GetOrderHash(order: Order) {
  return {
    ...Type.OrderSchema,
    message: order,
  }
}

export interface Signature {
  signer: string
  expiration: BigInt // expiration timestamp in nano seconds
  r: Buffer
  s: Buffer
  v: number
  nonce: number
}

// Liquidation
export function GetLiquidationHash(liquidationOrder: LiquidationOrder) {
  return {
    ...Type.LiquidationOrderSchema,
    message: liquidationOrder,
  }
}

export function Sign(wallet: Wallet, msgParams: any): Signature {
  const sig = signTypedData({
    privateKey: buf(wallet.privateKey),
    data: msgParams,
    version: SignTypedDataVersion.V4,
  })

  // ethers-6 const { r, s, v } = EtherSig.from(sig)
  const { r, s, v } = utils.splitSignature(sig)

  // console.log("sig", sig)
  // console.log("r", r, "s", s, "v", v)
  return {
    signer: wallet.address,
    expiration: msgParams.message.expiration.toString(),
    r: buf(r),
    s: buf(s),
    v,
    nonce: msgParams.message.nonce,
  }
}

function buf(s: string): Buffer {
  return Buffer.from(s.substring(2), "hex")
}