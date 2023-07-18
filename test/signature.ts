import { SignTypedDataVersion, signTypedData } from '@metamask/eth-sig-util'
import { Wallet, utils } from 'ethers'
import { buf, getTimestamp } from './util'
import * as Types from '../message/types'
import { randomInt } from 'crypto'

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

function sign(wallet: Wallet, msgParams: any): Signature {
  const sig = signTypedData({
    privateKey: buf(wallet.privateKey),
    data: msgParams,
    version: SignTypedDataVersion.V4,
  })
  // console.log(
  //   '🦊 MetamaskSig      = ',
  //   sig.toLocaleLowerCase().substring(0, 50) + '...'
  // )
  const { r, s, v } = utils.splitSignature(sig)
  return {
    signer: wallet.address,
    expiration: getTimestamp(),
    r: buf(r),
    s: buf(s),
    v,
  }
}
