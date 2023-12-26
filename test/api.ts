import { Wallet } from "ethers"
import { GRVTExchange } from "../typechain-types/index"
import {
  genAddAccountAdminSig as genAddAccountSignerSig,
  genAddAccountGuardianPayloadSig,
  genAddSessionKeySig,
  genAddSubAccountSignerPayloadSig,
  genAddTransferSubAccountPayloadSig,
  genAddWithdrawalAddressSig,
  genCreateAccountSig,
  genCreateSubAccountSig,
  genDepositSig,
  genRecoverAccountAdminPayloadSig,
  genRemoveAccountSignerSig,
  genRemoveAccountGuardianPayloadSig,
  genRemoveSubAccountSignerPayloadSig,
  genRemoveTransferSubAccountPayloadSig,
  genRemoveWithdrawalAddressSig,
  genScheduleConfigSig,
  genSetAccountMultiSigThresholdSig,
  genSetConfigSig,
  genSetSubAccountMarginTypePayloadSig,
  genSetSubAccountSignerPermissionsPayloadSig,
  genTransferSig,
  genWithdrawalSig,
} from "./signature"
import { AccountRecoveryType, Currency, MarginType } from "./type"
import { Bytes32, nonce } from "./util"

export const MAX_GAS = 2_000_000_000

// Account
export async function createAccount(contract: GRVTExchange, txSigner: Wallet, ts: number, txID: number, accID: string) {
  const salt = nonce()
  const sig = genCreateAccountSig(txSigner, accID, salt)
  return await contract.createAccount(ts, txID, accID, sig, { gasLimit: MAX_GAS })
}

export async function createSubAccount(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  accID: string,
  subID: number
) {
  const salt = nonce()
  const sig = genCreateSubAccountSig(txSigner, accID, subID, Currency.USDC, MarginType.PORTFOLIO_CROSS_MARGIN, salt)
  return contract.createSubAccount(
    ts,
    txID,
    accID,
    subID,
    Currency.USDC,
    MarginType.PORTFOLIO_CROSS_MARGIN,
    salt,
    sig,
    { gasLimit: MAX_GAS }
  )
}

export async function addAccountSigner(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string,
  permissions: number
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountSignerSig(txSigner, accID, signer, permissions, salt))
  return contract.addAccountSigner(ts, txID, accID, signer, permissions, salt, sigs, { gasLimit: MAX_GAS })
}

export async function removeAccountSigner(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountSignerSig(txSigner, accID, signer, salt))
  return contract.removeAccountSigner(ts, txID, accID, signer, salt, sigs, { gasLimit: MAX_GAS })
}

export async function setMultisigThreshold(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  multiSigThreshold: number
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genSetAccountMultiSigThresholdSig(txSigner, accID, multiSigThreshold, salt))
  return contract.setAccountMultiSigThreshold(ts, txID, accID, multiSigThreshold, salt, sigs, {
    gasLimit: MAX_GAS,
  })
}

export async function addWithdrawalAddress(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  withdrawalAddress: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddWithdrawalAddressSig(txSigner, accID, withdrawalAddress, salt))
  return contract.addWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, { gasLimit: MAX_GAS })
}

export async function removeWithdrawalAddress(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  withdrawalAddress: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveWithdrawalAddressSig(txSigner, accID, withdrawalAddress, salt))
  return contract.removeWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, {
    gasLimit: MAX_GAS,
  })
}

// export async function addTransferSubAccount(
//   contract: GRVTExchange,
//   txSigners: Wallet[],
//   ts: number,
//   txID: number,
//   accID: string,
//   subID: number
// ) {
//   const salt = nonce()
//   const sigs = txSigners.map((txSigner) => genAddTransferSubAccountPayloadSig(txSigner, accID, subID, salt))
// return contract.addTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
//
// }

// export async function removeTransferSubAccount(
//   contract: GRVTExchange,
//   txSigners: Wallet[],
//   ts: number,
//   txID: number,
//   accID: string,
//   subID: number
// ) {
//   const salt = nonce()
//   const sigs = txSigners.map((txSigner) => genRemoveTransferSubAccountPayloadSig(txSigner, accID, subID, salt))
// return contract.removeTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
//
// }

// Sub Account
export async function setSubAccountMarginType(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: number,
  marginType: MarginType
) {
  const salt = nonce()
  const sig = genSetSubAccountMarginTypePayloadSig(txSigner, subID, marginType, salt)
  return contract.setSubAccountMarginType(ts, txID, subID, marginType, salt, sig, { gasLimit: MAX_GAS })
}

export async function addSubSigner(
  contract: GRVTExchange,
  ts: number,
  txID: number,
  txSigner: Wallet,
  subID: number,
  newSigner: string,
  permission: number
) {
  const salt = nonce()
  const sig = genAddSubAccountSignerPayloadSig(txSigner, subID, newSigner, permission, salt)
  return contract.addSubAccountSigner(ts, txID, subID, newSigner, permission, salt, sig, {
    gasLimit: MAX_GAS,
  })
}

export async function setSubAccountSignerPermission(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: number,
  signer: string,
  permission: number
) {
  const salt = nonce()
  const sig = genSetSubAccountSignerPermissionsPayloadSig(txSigner, subID, signer, permission, salt)
  return contract.SetSubAccountSignerPermissions(ts, txID, subID, signer, permission, salt, sig, {
    gasLimit: MAX_GAS,
  })
}

export async function removeSubSigner(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: number,
  signer: string
) {
  const salt = nonce()
  const sig = genRemoveSubAccountSignerPayloadSig(txSigner, subID, signer, salt)
  return contract.removeSubAccountSigner(ts, txID, subID, signer, salt, sig, { gasLimit: MAX_GAS })
}

// Account Recovery
export async function addAccountGuardian(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  guardian: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountGuardianPayloadSig(txSigner, accID, guardian, salt))
  return contract.addAccountGuardian(ts, txID, accID, guardian, salt, sigs, { gasLimit: MAX_GAS })
}

export async function removeAccountGuardian(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountGuardianPayloadSig(txSigner, accID, signer, salt))
  return contract.removeAccountGuardian(ts, txID, accID, signer, salt, sigs, { gasLimit: MAX_GAS })
}

export async function recoverAccountAdmin(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accountID: string,
  recoveryType: AccountRecoveryType,
  oldAdmin: string,
  recoveryAdmin: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) =>
    genRecoverAccountAdminPayloadSig(txSigner, accountID, recoveryType, oldAdmin, recoveryAdmin, salt)
  )
  return contract.recoverAccountAdmin(ts, txID, accountID, recoveryType, oldAdmin, recoveryAdmin, salt, sigs, {
    gasLimit: MAX_GAS,
  })
}

// Config
export async function scheduleConfig(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  key: number,
  value: Bytes32
) {
  const salt = nonce()
  const sig = genScheduleConfigSig(txSigner, key, value, salt)
  return contract.scheduleConfig(ts, txID, key, value, salt, sig, { gasLimit: MAX_GAS })
}

export async function setConfig(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  key: number,
  value: Bytes32
) {
  const salt = nonce()
  const sig = genSetConfigSig(txSigner, key, value, salt)
  return contract.setConfig(ts, txID, key, value, salt, sig, { gasLimit: MAX_GAS })
}

// Session
export async function addSessionKey(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  sessionKey: string,
  keyExpiry: number
) {
  const sig = genAddSessionKeySig(txSigner, sessionKey, keyExpiry)
  return contract.addSessionKey(ts, txID, sessionKey, keyExpiry, sig, { gasLimit: MAX_GAS })
}

export async function removeSessionKey(contract: GRVTExchange, txSigner: Wallet, ts: number, txID: number) {
  return contract.removeSessionKey(ts, txID, txSigner.address)
}

// Trade
// Transfer

export async function deposit(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  fromEthAddress: string,
  toSubAccount: string,
  numTokens: number
) {
  const salt = nonce()
  const sig = genDepositSig(txSigner, fromEthAddress, toSubAccount, numTokens, salt)
  return contract.deposit(ts, txID, fromEthAddress, toSubAccount, numTokens, salt, sig, { gasLimit: MAX_GAS })
}

export async function withdraw(
  contract: GRVTExchange,
  txSigner: Wallet,
  ts: number,
  txID: number,
  fromSubAccount: string,
  toEthAddress: string,
  numTokens: number
) {
  const salt = nonce()
  const sig = genWithdrawalSig(txSigner, fromSubAccount, toEthAddress, numTokens, salt)
  return contract.withdrawal(ts, txID, fromSubAccount, toEthAddress, numTokens, salt, sig, {
    gasLimit: MAX_GAS,
  })
}

// export async function transfer(
//   contract: GRVTExchange,
//   txSigner: Wallet,
//   ts: number,
//   txID: number,
//   fromSubAccount: string,
//   toSubAccount: string,
//   numTokens: number
// ) {
//   const salt = nonce()
//   const sig = genTransferSig(txSigner, fromSubAccount, toSubAccount, numTokens, salt)
// return contract.transfer(ts, txID, fromSubAccount, toSubAccount, numTokens, salt, sig, {gasLimit: MAX_GAS})
// }
