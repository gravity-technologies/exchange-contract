import { SignTypedDataVersion, signTypedData } from "@metamask/eth-sig-util"
import { randomInt } from "crypto"
import { BaseWallet, Signature as EtherSig, Wallet } from "ethers"
import * as Types from "../signatures/message/type"
import { OrderNoSignature, Signature } from "./type"
import { buf, getTimestampNs } from "./util"

export function genCreateAccountSig(
  wallet: BaseWallet,
  accountID: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.CreateAccount,
    message: {
      accountID,
      nonce,
    },
  })
}

export function genCreateSubAccountSig(
  wallet: BaseWallet,
  accountID: string,
  subAccountID: number,
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
  wallet: BaseWallet,
  accountID: string,
  signer: string,
  permissions: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddAccountSigner,
    message: {
      accountID,
      signer,
      permissions,
      nonce,
    },
  })
}

export function genSetAccountMultiSigThresholdSig(
  wallet: BaseWallet,
  accountID: string,
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

export function genRemoveAccountSignerSig(
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  subAccountID: number,
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
  wallet: BaseWallet,
  subAccountID: number,
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
  wallet: BaseWallet,
  subAccountID: number,
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
  wallet: BaseWallet,
  subAccountID: number,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
  accountID: string,
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
  wallet: BaseWallet,
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
  wallet: BaseWallet,
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
export function genAddSessionKeySig(wallet: BaseWallet, sessionKey: string, keyExpiry: number): Signature {
  return sign(wallet, {
    ...Types.AddSessionKey,
    message: {
      sessionKey,
      keyExpiry,
    },
  })
}

export function genRemoveSessionKeySig(wallet: BaseWallet): Signature {
  // just generate a random signature, as long as the signer is correct
  return genAddSessionKeySig(wallet, "0x12345", 10000000)
}

// Trade
export function genOrderSig(wallet: BaseWallet, order: OrderNoSignature): Signature {
  return sign(wallet, {
    ...Types.Order,
    message: order,
  })
}

// Transfer
export function genDepositSig(
  wallet: BaseWallet,
  fromEthAddress: string,
  toSubaccount: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.Deposit,
    message: {
      fromEthAddress,
      toSubaccount,
      numTokens,
      nonce,
    },
  })
}

export function genWithdrawalSig(
  wallet: BaseWallet,
  fromSubaccount: string,
  toEthAddress: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.Withdrawal,
    message: {
      fromSubaccount,
      toEthAddress,
      numTokens,
      nonce,
    },
  })
}

export function genTransferSig(
  wallet: BaseWallet,
  fromSubaccount: string,
  toSubaccount: string,
  numTokens: number,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.Transfer,
    message: {
      fromSubaccount,
      toSubaccount,
      numTokens,
      nonce,
    },
  })
}

function sign(wallet: BaseWallet, msgParams: any): Signature {
  // console.log("msg", msgParams.primaryType, msgParams.message)
  const sig = signTypedData({
    privateKey: buf(wallet.privateKey),
    data: msgParams,
    version: SignTypedDataVersion.V4,
  })

  const { r, s, v } = EtherSig.from(sig)

  // console.log("sig", sig)
  // console.log("r", r, "s", s, "v", v)
  return {
    signer: wallet.address,
    expiration: getTimestampNs(),
    r: buf(r),
    s: buf(s),
    v,
    nonce: msgParams.message.nonce,
  }
}
