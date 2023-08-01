import { SignTypedDataVersion, signTypedData } from "@metamask/eth-sig-util"
import { Wallet, utils } from "ethers"
import { buf, getTimestampNs } from "./util"
import * as Types from "../message/type"
import { randomInt } from "crypto"
import { OrderNoSignature, Signature } from "./type"

export function genCreateSubAccountSig(
  wallet: Wallet,
  accountID: number,
  subAccountID: string,
  quoteCurrency: number,
  marginType: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.CreateSubAccount,
    message: {
      accountID,
      subAccountID,
      quoteCurrency,
      marginType,
      nonce,
    },
  })
}

export function genAddAccountAdminSig(
  wallet: Wallet,
  accountID: number,
  signer: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddAccountSigner,
    message: {
      accountID,
      signer,
      nonce,
    },
  })
}

export function genSetAccountMultiSigThresholdSig(
  wallet: Wallet,
  accountID: number,
  multiSigThreshold: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.SetAccountMultiSigThreshold,
    message: {
      accountID,
      multiSigThreshold,
      nonce,
    },
  })
}

export function genRemoveAccountAdminSig(
  wallet: Wallet,
  accountID: number,
  signer: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveAccountSigner,
    message: {
      accountID,
      signer,
      nonce,
    },
  })
}

export function genAddWithdrawalAddressSig(
  wallet: Wallet,
  accountID: number,
  withdrawalAddress: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
    },
  })
}

export function genRemoveWithdrawalAddressSig(
  wallet: Wallet,
  accountID: number,
  withdrawalAddress: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveWithdrawalAddress,
    message: {
      accountID,
      withdrawalAddress,
      nonce,
    },
  })
}

export function genAddTransferSubAccountPayloadSig(
  wallet: Wallet,
  accountID: number,
  transferSubAccount: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddTransferSubAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
    },
  })
}

export function genRemoveTransferSubAccountPayloadSig(
  wallet: Wallet,
  accountID: number,
  transferSubAccount: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveTransferSubAccount,
    message: {
      accountID,
      transferSubAccount,
      nonce,
    },
  })
}

// SubAccount
export function genSetSubAccountMarginTypePayloadSig(
  wallet: Wallet,
  subAccountID: string,
  marginType: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.SetSubAccountMarginType,
    message: {
      subAccountID,
      marginType,
      nonce,
    },
  })
}

export function genAddSubAccountSignerPayloadSig(
  wallet: Wallet,
  subAccountID: string,
  signer: string,
  permissions: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddSubAccountSigner,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
    },
  })
}

export function genSetSubAccountSignerPermissionsPayloadSig(
  wallet: Wallet,
  subAccountID: string,
  signer: string,
  permissions: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.SetSubAccountSignerPermissions,
    message: {
      subAccountID,
      signer,
      permissions,
      nonce,
    },
  })
}

export function genRemoveSubAccountSignerPayloadSig(
  wallet: Wallet,
  subAccountID: string,
  signer: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveSubAccountSigner,
    message: {
      subAccountID,
      signer,
      nonce,
    },
  })
}

// Account Recovery
export function genAddAccountGuardianPayloadSig(
  wallet: Wallet,
  accountID: number,
  signer: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddAccountGuardian,
    message: {
      accountID,
      signer,
      nonce,
    },
  })
}

export function genRemoveAccountGuardianPayloadSig(
  wallet: Wallet,
  accountID: number,
  signer: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveAccountGuardian,
    message: {
      accountID,
      signer,
      nonce,
    },
  })
}

export function genRecoverAccountAdminPayloadSig(
  wallet: Wallet,
  accountID: number,
  recoveryType: number,
  oldAdmin: string,
  recoveryAdmin: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RecoverAccountAdmin,
    message: {
      accountID,
      recoveryType,
      oldAdmin,
      recoveryAdmin,
      nonce,
    },
  })
}

// Config
export function genScheduleConfigSig(
  wallet: Wallet,
  key: number,
  value: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.ScheduleConfig,
    message: {
      key,
      value,
      nonce,
    },
  })
}

export function genSetConfigSig(
  wallet: Wallet,
  key: number,
  value: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.SetConfig,
    message: {
      key,
      value,
      nonce,
    },
  })
}

// Session
export function genAddSessionKeySig(wallet: Wallet, sessionKey: string, keyExpiry: number): Signature {
  return sign(wallet, {
    ...Types.AddSessionKey,
    message: {
      sessionKey,
      keyExpiry,
    },
  })
}

export function genRemoveSessionKeySig(wallet: Wallet): Signature {
  // just generate a random signature, as long as the signer is correct
  return genAddSessionKeySig(wallet, "0x12345", 10000000)
}

// Trade
export function genOrderSig(wallet: Wallet, order: OrderNoSignature): Signature {
  return sign(wallet, {
    ...Types.OrderPayload,
    message: order,
  })
}

// Transfer
export function genDepositSig(
  wallet: Wallet,
  fromEthAddress: string,
  toSubaccount: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.DepositPayload,
    message: {
      fromEthAddress,
      toSubaccount,
      numTokens,
      nonce,
    },
  })
}

export function genWithdrawalSig(
  wallet: Wallet,
  fromSubaccount: string,
  toEthAddress: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.WithdrawalPayload,
    message: {
      fromSubaccount,
      toEthAddress,
      numTokens,
      nonce,
    },
  })
}

export function genTransferSig(
  wallet: Wallet,
  fromSubaccount: string,
  toSubaccount: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.TransferPayload,
    message: {
      fromSubaccount,
      toSubaccount,
      numTokens,
      nonce,
    },
  })
}

function sign(wallet: Wallet, msgParams: any): Signature {
  // console.log("msg", msgParams.primaryType, msgParams.message)
  const sig = signTypedData({
    privateKey: buf(wallet.privateKey),
    data: msgParams,
    version: SignTypedDataVersion.V4,
  })

  // console.log("sig", sig)
  const { r, s, v } = utils.splitSignature(sig)
  return {
    signer: wallet.address,
    expiration: getTimestampNs(),
    r: buf(r),
    s: buf(s),
    v,
    nonce: msgParams.message.nonce,
  }
}
