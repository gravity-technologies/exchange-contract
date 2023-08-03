import { SignTypedDataVersion, signTypedData } from "@metamask/eth-sig-util"
import { Wallet, utils } from "ethers"
import { buf, getTimestampNs } from "./util"
import * as Types from "../message/types"
import { randomInt } from "crypto"

interface Signature {
  signer: string
  expiration: number // expiration timestamp in nano seconds
  r: Buffer
  s: Buffer
  v: number
}

export function genCreateSubAccountSig(
  wallet: Wallet,
  accountID: number,
  subAccountID: string,
  quoteCurrency: number,
  marginType: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.CreateSubAccountPayload,
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
    ...Types.AddAccountAdminPayload,
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
    ...Types.SetAccountMultiSigThresholdPayload,
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
    ...Types.RemoveAccountAdminPayload,
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
    ...Types.AddWithdrawalAddressPayload,
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
    ...Types.RemoveWithdrawalAddressPayload,
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
    ...Types.AddTransferSubAccountPayload,
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
    ...Types.RemoveTransferSubAccountPayload,
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
    ...Types.SetSubAccountMarginTypePayload,
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
    ...Types.AddSubAccountSignerPayload,
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
    ...Types.SetSubAccountSignerPermissionsPayload,
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
    ...Types.RemoveSubAccountSignerPayload,
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
    ...Types.AddAccountGuardianPayload,
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
    ...Types.RemoveAccountGuardianPayload,
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
    ...Types.RecoverAccountAdminPayload,
    message: {
      accountID,
      recoveryType,
      oldAdmin,
      recoveryAdmin,
      nonce,
    },
  })
}

// Session
export function genAddSessionKeySig(
  wallet: Wallet,
  subAccountID: string,
  sessionKey: string,
  expiry: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddSessionKeyPayload,
    message: {
      subAccountID,
      sessionKey,
      expiry,
      nonce,
    },
  })
}

export function genRemoveSessionKeySig(
  wallet: Wallet,
  subAccountID: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveSessionKeyPayload,
    message: {
      subAccountID,
      nonce,
    },
  })
}

// Transfer
export function genDepositSig(
  wallet: Wallet,
  fromEthAddress: string,
  toSubaccount: string,
  numTokens: number
): Signature {
  return sign(wallet, {
    ...Types.DepositPayload,
    message: {
      fromEthAddress,
      toSubaccount,
      numTokens,
    },
  })
}

export function genWithdrawalSig(
  wallet: Wallet,
  fromSubaccount: string,
  toEthAddress: string,
  numTokens: number
): Signature {
  return sign(wallet, {
    ...Types.WithdrawalPayload,
    message: {
      fromSubaccount,
      toEthAddress,
      numTokens,
    },
  })
}

export function genTransferSig(
  wallet: Wallet,
  fromSubaccount: string,
  toSubaccount: string,
  numTokens: number
): Signature {
  return sign(wallet, {
    ...Types.TransferPayload,
    message: {
      fromSubaccount,
      toSubaccount,
      numTokens,
    },
  })
}

function sign(wallet: Wallet, msgParams: any): Signature {
  const sig = signTypedData({
    privateKey: buf(wallet.privateKey),
    data: msgParams,
    version: SignTypedDataVersion.V4,
  })
  const { r, s, v } = utils.splitSignature(sig)
  return {
    signer: wallet.address,
    expiration: getTimestampNs(),
    r: buf(r),
    s: buf(s),
    v,
  }
}
