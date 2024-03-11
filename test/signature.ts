import { SignTypedDataVersion, signTypedData } from "@metamask/eth-sig-util"
import { randomInt } from "crypto"
import { Wallet, utils } from "ethers"
import * as Types from "../signatures/message/type"
import { OrderNoSignature, ZKSyncMysteryBoxDefiTaskSignature, Signature, PriceEntry, PriceEntrySig } from "./type"
import { buf, getTimestampNs } from "./util"

export function genCreateAccountSig(wallet: Wallet, accountID: string, nonce: number = randomInt(22021991)): Signature {
  return sign(wallet, {
    ...Types.CreateAccount,
    message: {
      accountID,
      nonce,
    },
  })
}

export function genCreateSubAccountSig(
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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
  wallet: Wallet,
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

export function genRemoveSubAccountSignerPayloadSig(
  wallet: Wallet,
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
// Wallet Recovery
export function genAddRecoveryAddressPayloadSig(
  wallet: Wallet,
  accountID: string,
  recoverySigner: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddRecoveryAddress,
    message: {
      accountID,
      recoverySigner,
      nonce,
    },
  })
}

export function genRemoveRecoveryAddressPayloadSig(
  wallet: Wallet,
  accountID: string,
  recoverySigner: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RemoveRecoveryAddress,
    message: {
      accountID,
      recoverySigner,
      nonce,
    },
  })
}

export function genRecoverAddressPayloadSig(
  wallet: Wallet,
  accountID: string,
  oldSigner: string,
  newSigner: string,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.RecoverAddress,
    message: {
      accountID,
      oldSigner,
      newSigner,
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
export function genAddSessionKeySig(
  wallet: Wallet,
  sessionKey: string,
  keyExpiry: BigInt,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.AddSessionKey,
    message: {
      sessionKey,
      keyExpiry,
      nonce,
    },
  })
}

// Trade
export function genOrderSig(wallet: Wallet, order: OrderNoSignature): Signature {
  return sign(wallet, {
    ...Types.Order,
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
  wallet: Wallet,
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
  wallet: Wallet,
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

export function genPriceTick(
  wallet: Wallet,
  values: PriceEntrySig[],
  timestamp: BigInt,
  nonce: number = randomInt(22021991)
): Signature {
  return sign(wallet, {
    ...Types.OracleData,
    message: {
      values,
      timestamp,
      nonce,
    },
  })
}

// ZKSyncMysteryBoxDefiTask
export function genZKSyncMysteryBoxDefiTaskSig(wallet: Wallet, task: ZKSyncMysteryBoxDefiTaskSignature): Signature {
  return sign(wallet, {
    ...Types.ZKSynvMysteryBoxDefiTask,
    message: task,
  })
}

function sign(wallet: Wallet, msgParams: any): Signature {
  // console.log("msg", msgParams.primaryType, msgParams.message)
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
    expiration: getTimestampNs(),
    r: buf(r),
    s: buf(s),
    v,
    nonce: msgParams.message.nonce,
  }
}
