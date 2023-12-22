import { Wallet } from "ethers"
import { GRVTExchange } from "../typechain-types/index"
import {
  genAddAccountAdminSig,
  genAddAccountGuardianPayloadSig,
  genAddSessionKeySig,
  genAddSubAccountSignerPayloadSig,
  genAddTransferSubAccountPayloadSig,
  genAddWithdrawalAddressSig,
  genCreateAccountSig,
  genCreateSubAccountSig,
  genDepositSig,
  genRecoverAccountAdminPayloadSig,
  genRemoveAccountAdminSig,
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

const MAX_GAS = 2_000_000_000

// Account
export async function createAccount(contract: GRVTExchange, txSigner: Wallet, ts: number, txID: number, accID: string) {
  const salt = nonce()
  const sig = genCreateAccountSig(txSigner, accID, salt)
  const tx = await contract.createAccount(ts, txID, accID, sig, { gasLimit: MAX_GAS })
  await tx.wait()
}

export async function createSubAcc(
  contract: GRVTExchange,
  txSigner: Wallet,
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
    [sig]
  )
  await tx.wait()
}

export async function addAccAdmin(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountAdminSig(txSigner, accID, signer, salt))
  const tx = await contract.addAccountAdmin(ts, txID, accID, signer, salt, sigs, { gasLimit: MAX_GAS })
  await tx.wait()
}

export async function removeAccAdmin(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountAdminSig(txSigner, accID, signer, salt))
  const tx = await contract.removeAccountAdmin(ts, txID, accID, signer, salt, sigs, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.setAccountMultiSigThreshold(ts, txID, accID, multiSigThreshold, salt, sigs, {
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
  const tx = await contract.addWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.removeWithdrawalAddress(ts, txID, accID, withdrawalAddress, salt, sigs, {
    gasLimit: MAX_GAS,
  })
  await tx.wait()
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
// const tx = await contract.addTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
// await tx.wait()
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
// const tx = await contract.removeTransferSubAccount(ts, txID, accID, subID, salt, sigs, {gasLimit: MAX_GAS})
// await tx.wait()
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
  const tx = await contract.setSubAccountMarginType(ts, txID, subID, marginType, salt, sig, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.addSubAccountSigner(ts, txID, subID, newSigner, permission, salt, sig, {
    gasLimit: MAX_GAS,
  })
  await tx.wait()
}

export async function setSignerPermission(
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
  const tx = await contract.SetSubAccountSignerPermissions(ts, txID, subID, signer, permission, salt, sig, {
    gasLimit: MAX_GAS,
  })
  await tx.wait()
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
  const tx = await contract.removeSubAccountSigner(ts, txID, subID, signer, salt, sig, { gasLimit: MAX_GAS })
  await tx.wait()
}

// Account Recovery
export async function addAccGuardian(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  guardian: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genAddAccountGuardianPayloadSig(txSigner, accID, guardian, salt))
  const tx = await contract.addAccountGuardian(ts, txID, accID, guardian, salt, sigs, { gasLimit: MAX_GAS })
  await tx.wait()
}

export async function removeAccGuardian(
  contract: GRVTExchange,
  txSigners: Wallet[],
  ts: number,
  txID: number,
  accID: string,
  signer: string
) {
  const salt = nonce()
  const sigs = txSigners.map((txSigner) => genRemoveAccountGuardianPayloadSig(txSigner, accID, signer, salt))
  const tx = await contract.removeAccountGuardian(ts, txID, accID, signer, salt, sigs, { gasLimit: MAX_GAS })
  await tx.wait()
}

export async function recoverAccAdmin(
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
  const tx = await contract.recoverAccountAdmin(
    ts,
    txID,
    accountID,
    recoveryType,
    oldAdmin,
    recoveryAdmin,
    salt,
    sigs,
    {
      gasLimit: MAX_GAS,
    }
  )
  await tx.wait()
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
  const tx = await contract.scheduleConfig(ts, txID, key, value, salt, sig, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.setConfig(ts, txID, key, value, salt, sig, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.addSessionKey(ts, txID, sessionKey, keyExpiry, sig, { gasLimit: MAX_GAS })
}

export async function removeSessionKey(contract: GRVTExchange, txSigner: Wallet, ts: number, txID: number) {
  const tx = await contract.removeSessionKey(ts, txID, txSigner.address)
  await tx.wait()
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
  const tx = await contract.deposit(ts, txID, fromEthAddress, toSubAccount, numTokens, salt, sig, { gasLimit: MAX_GAS })
  await tx.wait()
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
  const tx = await contract.withdrawal(ts, txID, fromSubAccount, toEthAddress, numTokens, salt, sig, {
    gasLimit: MAX_GAS,
  })
  await tx.wait()
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
// const tx = await contract.transfer(ts, txID, fromSubAccount, toSubAccount, numTokens, salt, sig, {gasLimit: MAX_GAS})
// }
