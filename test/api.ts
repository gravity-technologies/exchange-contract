import { Contract, Wallet } from "ethers"
import {
  genAddAccountAdminSig,
  genAddAccountGuardianPayloadSig,
  genAddSessionKeySig,
  genAddSubAccountSignerPayloadSig,
  genCreateSubAccountSig,
  genRecoverAccountAdminPayloadSig,
  genRemoveAccountGuardianPayloadSig,
  genRemoveSessionKeySig,
  genRemoveSubAccountSignerPayloadSig,
  genSetAccountMultiSigThresholdSig,
  genSetSubAccountMarginTypePayloadSig,
  genSetSubAccountSignerPermissionsPayloadSig,
} from "./signature"
import { AccountRecoveryType, Currency, MarginType } from "./type"
import { nonce } from "./util"

// Account
export async function createSubAcc(
  contract: Contract,
  txSigner: Wallet,
  ts: number,
  txID: number,
  accID: number,
  subID: string
) {
  const salt = nonce()
  const sig = genCreateSubAccountSig(txSigner, accID, subID, Currency.USDC, MarginType.PORTFOLIO_CROSS_MARGIN, salt)
  await contract.createSubAccount(ts, txID, accID, subID, Currency.USDC, MarginType.PORTFOLIO_CROSS_MARGIN, salt, [sig])
}

export async function addAccAdmin(
  contract: Contract,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: number,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountAdminSig(txSigner, accID, signer, salt))
  await contract.addAccountAdmin(ts, txID, accID, signer, salt, sigs)
}

export async function setMultisigThreshold(
  contract: Contract,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: number,
  multiSigThreshold: number
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genSetAccountMultiSigThresholdSig(txSigner, accID, multiSigThreshold, salt))
  await contract.setAccountMultiSigThreshold(ts, txID, accID, multiSigThreshold, salt, sigs)
}

// Sub Account
export async function setSubAccountMarginType(
  contract: Contract,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: string,
  marginType: MarginType
) {
  const salt = nonce()
  const sig = genSetSubAccountMarginTypePayloadSig(txSigner, subID, marginType, salt)
  await contract.setSubAccountMarginType(ts, txID, subID, marginType, salt, sig)
}

export async function addSubSigner(
  contract: Contract,
  ts: number,
  txID: number,
  txSigner: Wallet,
  subID: string,
  newSigner: string,
  permission: number
) {
  const salt = nonce()
  const sig = genAddSubAccountSignerPayloadSig(txSigner, subID, newSigner, permission, salt)
  await contract.addSubAccountSigner(ts, txID, subID, newSigner, permission, salt, sig)
}

export async function setSignerPermission(
  contract: Contract,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: string,
  signer: string,
  permission: number
) {
  const salt = nonce()
  const sig = genSetSubAccountSignerPermissionsPayloadSig(txSigner, subID, signer, permission, salt)
  await contract.setSubAccountSignerPermissions(ts, txID, subID, signer, permission, salt, sig)
}

export async function removeSubSigner(
  contract: Contract,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: string,
  signer: string
) {
  const salt = nonce()
  const sig = genRemoveSubAccountSignerPayloadSig(txSigner, subID, signer, salt)
  await contract.removeSubAccountSigner(ts, txID, subID, signer, salt, sig)
}

// Account Recovery
export async function addAccGuardian(
  contract: Contract,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: number,
  guardian: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountGuardianPayloadSig(txSigner, accID, guardian, salt))
  await contract.addAccountGuardian(ts, txID, accID, guardian, salt, sigs)
}

export async function removeAccGuardian(
  contract: Contract,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: number,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountGuardianPayloadSig(txSigner, accID, signer, salt))
  await contract.removeAccountGuardian(ts, txID, accID, signer, salt, sigs)
}

export async function recoverAccAdmin(
  contract: Contract,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accountID: number,
  recoveryType: AccountRecoveryType,
  oldAdmin: string,
  recoveryAdmin: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) =>
    genRecoverAccountAdminPayloadSig(txSigner, accountID, recoveryType, oldAdmin, recoveryAdmin, salt)
  )
  await contract.recoverAccountAdmin(ts, txID, accountID, recoveryType, oldAdmin, recoveryAdmin, salt, sigs)
}

// Session
export async function addSessionKey(
  contract: Contract,
  txSigner: Wallet,
  ts: number,
  txID: number,
  subID: string,
  sessionKey: string,
  expiry: number
) {
  const salt = nonce()
  const sig = genAddSessionKeySig(txSigner, subID, sessionKey, expiry, salt)
  await contract.addSessionKey(ts, txID, subID, sessionKey, expiry, salt, sig)
}

export async function removeSessionKey(contract: Contract, txSigner: Wallet, ts: number, txID: number, subID: string) {
  const salt = nonce()
  const sig = genRemoveSessionKeySig(txSigner, subID, salt)
  await contract.removeSessionKey(ts, txID, subID, salt, sig)
}
