import { BaseWallet, TransactionRequest } from "ethers"
import { Contract } from "zksync-ethers"
import {
  genAddAccountGuardianPayloadSig,
  genAddAccountAdminSig as genAddAccountSignerSig,
  genAddSessionKeySig,
  genAddSubAccountSignerPayloadSig,
  genAddWithdrawalAddressSig,
  genCreateAccountSig,
  genCreateSubAccountSig,
  genDepositSig,
  genRecoverAccountAdminPayloadSig,
  genRemoveAccountGuardianPayloadSig,
  genRemoveAccountSignerSig,
  genRemoveSubAccountSignerPayloadSig,
  genRemoveWithdrawalAddressSig,
  genScheduleConfigSig,
  genSetAccountMultiSigThresholdSig,
  genSetConfigSig,
  genSetSubAccountMarginTypePayloadSig,
  genSetSubAccountSignerPermissionsPayloadSig,
  genWithdrawalSig,
} from "./signature"
import { AccountRecoveryType, Currency, MarginType } from "./type"
import { Bytes32, nonce } from "./util"

export const MAX_GAS = 2_000_000_000

function txRequestDefault(): TransactionRequest {
  return {
    gasLimit: MAX_GAS,
  }
}

// Account
export async function createAccount(contract: Contract, txSigner: BaseWallet, ts: number, txID: number, accID: string) {
  const salt = nonce()
  const sig = genCreateAccountSig(txSigner, accID, salt)
  const tx = await contract.createAccount(ts, txID, accID, sig, txRequestDefault())
  await tx.wait()
}

export async function createSubAccount(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  accID: string,
  subID: number
) {
  const salt = nonce()
  const sig = genCreateSubAccountSig(txSigner, accID, subID, Currency.USDC, MarginType.PORTFOLIO_CROSS_MARGIN, salt)
  const tx = await contract.createSubAccount(
    ts,
    txID,
    accID,
    subID,
    Currency.USDC,
    MarginType.PORTFOLIO_CROSS_MARGIN,
    salt,
    sig,
    txRequestDefault()
  )
  await tx.wait()
}

export async function addAccountSigner(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string,
  permissions: number
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountSignerSig(txSigner, accID, signer, permissions, salt))
  const tx = await contract.addAccountSigner(ts, txID, accID, signer, permissions, salt, sigs, txRequestDefault())
  await tx.wait()
}

export async function removeAccountSigner(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountSignerSig(txSigner, accID, signer, salt))
  const tx = await contract.removeAccountSigner(ts, txID, accID, signer, salt, sigs, txRequestDefault())
  await tx.wait()
}

export async function setMultisigThreshold(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  multiSigThreshold: number
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genSetAccountMultiSigThresholdSig(txSigner, accID, multiSigThreshold, salt))
  const tx = await contract.setAccountMultiSigThreshold(
    ts,
    txID,
    accID,
    multiSigThreshold,
    salt,
    sigs,
    txRequestDefault()
  )
  await tx.wait()
}

export async function addWithdrawalAddress(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  withdrawalAddress: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddWithdrawalAddressSig(txSigner, accID, withdrawalAddress, salt))
  const tx = await contract.addWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, txRequestDefault())
  await tx.wait()
}

export async function removeWithdrawalAddress(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  withdrawalAddress: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveWithdrawalAddressSig(txSigner, accID, withdrawalAddress, salt))
  const tx = await contract.removeWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, txRequestDefault())
  await tx.wait()
}

// export async function addTransferSubAccount(
//   contract: Contract,
//   txSigners: BaseWallet[],
//   ts: number,
//   txID: number,
//   accID: string,
//   subID: number
// ) {
//   const salt = nonce()
//   const sigs = txSigners.map((txSigner) => genAddTransferSubAccountPayloadSig(txSigner, accID, subID, salt))
// const tx = await contract.addTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
// await tx.wait()
//
// }

// export async function removeTransferSubAccount(
//   contract: Contract,
//   txSigners: BaseWallet[],
//   ts: number,
//   txID: number,
//   accID: string,
//   subID: number
// ) {
//   const salt = nonce()
//   const sigs = txSigners.map((txSigner) => genRemoveTransferSubAccountPayloadSig(txSigner, accID, subID, salt))
// const tx = await contract.removeTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
// await tx.wait()
//
// }

// Sub Account
export async function setSubAccountMarginType(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  subID: number,
  marginType: MarginType
) {
  const salt = nonce()
  const sig = genSetSubAccountMarginTypePayloadSig(txSigner, subID, marginType, salt)
  const tx = await contract.setSubAccountMarginType(ts, txID, subID, marginType, salt, sig, txRequestDefault())
  await tx.wait()
}

export async function addSubSigner(
  contract: Contract,
  ts: number,
  txID: number,
  txSigner: BaseWallet,
  subID: number,
  newSigner: string,
  permission: number
) {
  const salt = nonce()
  const sig = genAddSubAccountSignerPayloadSig(txSigner, subID, newSigner, permission, salt)
  const tx = await contract.addSubAccountSigner(ts, txID, subID, newSigner, permission, salt, sig, txRequestDefault())
  await tx.wait()
}

export async function setSubAccountSignerPermission(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  subID: number,
  signer: string,
  permission: number
) {
  const salt = nonce()
  const sig = genSetSubAccountSignerPermissionsPayloadSig(txSigner, subID, signer, permission, salt)
  const tx = await contract.SetSubAccountSignerPermissions(
    ts,
    txID,
    subID,
    signer,
    permission,
    salt,
    sig,
    txRequestDefault()
  )
  await tx.wait()
}

export async function removeSubSigner(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  subID: number,
  signer: string
) {
  const salt = nonce()
  const sig = genRemoveSubAccountSignerPayloadSig(txSigner, subID, signer, salt)
  const tx = await contract.removeSubAccountSigner(ts, txID, subID, signer, salt, sig, txRequestDefault())
  await tx.wait()
}

// Account Recovery
export async function addAccountGuardian(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  guardian: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountGuardianPayloadSig(txSigner, accID, guardian, salt))
  const tx = await contract.addAccountGuardian(ts, txID, accID, guardian, salt, sigs, txRequestDefault())
  await tx.wait()
}

export async function removeAccountGuardian(
  contract: Contract,
  txSigners: BaseWallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountGuardianPayloadSig(txSigner, accID, signer, salt))
  const tx = await contract.removeAccountGuardian(ts, txID, accID, signer, salt, sigs, txRequestDefault())
  await tx.wait()
}

export async function recoverAccountAdmin(
  contract: Contract,
  txSigners: BaseWallet[],
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
  const tx = await contract.recoverAccountAdmin(
    ts,
    txID,
    accountID,
    recoveryType,
    oldAdmin,
    recoveryAdmin,
    salt,
    sigs,
    txRequestDefault()
  )
  await tx.wait()
}

// Config
export async function scheduleConfig(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  key: number,
  value: Bytes32
) {
  const salt = nonce()
  const sig = genScheduleConfigSig(txSigner, key, value, salt)
  const tx = await contract.scheduleConfig(ts, txID, key, value, salt, sig, txRequestDefault())
  await tx.wait()
}

export async function setConfig(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  key: number,
  value: Bytes32
) {
  const salt = nonce()
  const sig = genSetConfigSig(txSigner, key, value, salt)
  const tx = await contract.setConfig(ts, txID, key, value, salt, sig, txRequestDefault())
  await tx.wait()
}

// Session
export async function addSessionKey(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  sessionKey: string,
  keyExpiry: number
) {
  const sig = genAddSessionKeySig(txSigner, sessionKey, keyExpiry)
  const tx = await contract.addSessionKey(ts, txID, sessionKey, keyExpiry, sig, txRequestDefault())
  await tx.wait()
}

export async function removeSessionKey(contract: Contract, txSigner: BaseWallet, ts: number, txID: number) {
  const address = await txSigner.getAddress()
  const tx = await contract.removeSessionKey(ts, txID, address)
  await tx.wait()
}

// Trade
// Transfer

export async function deposit(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  fromEthAddress: string,
  toSubAccount: string,
  numTokens: number
) {
  const salt = nonce()
  const sig = genDepositSig(txSigner, fromEthAddress, toSubAccount, numTokens, salt)
  const tx = await contract.deposit(ts, txID, fromEthAddress, toSubAccount, numTokens, salt, sig, txRequestDefault())
  await tx.wait()
}

export async function withdraw(
  contract: Contract,
  txSigner: BaseWallet,
  ts: number,
  txID: number,
  fromSubAccount: string,
  toEthAddress: string,
  numTokens: number
) {
  const salt = nonce()
  const sig = genWithdrawalSig(txSigner, fromSubAccount, toEthAddress, numTokens, salt)
  const tx = await contract.withdrawal(ts, txID, fromSubAccount, toEthAddress, numTokens, salt, sig, txRequestDefault())
  await tx.wait()
}

// export async function transfer(
//   contract: Contract,
//   txSigner: BaseWallet,
//   ts: number,
//   txID: number,
//   fromSubAccount: string,
//   toSubAccount: string,
//   numTokens: number
// ) {
//   const salt = nonce()
//   const sig = genTransferSig(txSigner, fromSubAccount, toSubAccount, numTokens, salt)
// const tx = await contract.transfer(ts, txID, fromSubAccount, toSubAccount, numTokens, salt, sig, {gasLimit: MAX_GAS})
// await tx.wait()
// }
