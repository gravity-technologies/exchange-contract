import { Contract } from "ethers"
import {
  ExAccountMultiSigThreshold,
  ExAccountSigners,
  ExAccountWithdrawalAddresses,
  ExConfig1D,
  ExConfig2D,
  ExConfigSchedule,
  ExConfigScheduleAbsent,
  ExNumAccounts,
  ExSessionKeys,
  ExSubAccountSigners,
  ExSubAccountMarginType,
  Expectation,
} from "./TestEngineTypes"
import { expect } from "chai"

export function validateExpectation(contract: Contract, expectation: Expectation) {
  switch (expectation.name) {
    case "ExAccountSigners":
      return expectAccountSigners(contract, expectation.expect as ExAccountSigners)
    case "ExNumAccounts":
      return expectNumAccounts(contract, expectation.expect as ExNumAccounts)
    case "ExSessionKeys":
      return expectSessionKeys(contract, expectation.expect as ExSessionKeys)
    case "ExAccountMultiSigThreshold":
      return expectAccountMultisigThreshold(contract, expectation.expect as ExAccountMultiSigThreshold)
    case "ExAccountWithdrawalAddresses":
      return expectWithdrawalAddresses(contract, expectation.expect as ExAccountWithdrawalAddresses)
    case "ExConfig2D":
      return expectConfig2D(contract, expectation.expect as ExConfig2D)
    case "ExConfig":
      return expectConfig1D(contract, expectation.expect as ExConfig1D)
    case "ExConfigSchedule":
      return expectConfigSchedule(contract, expectation.expect as ExConfigSchedule)
    case "ExConfigScheduleAbsent":
      return expectConfigScheduleAbsent(contract, expectation.expect as ExConfigScheduleAbsent)
    case "ExSubAccountSigners":
      return expectSubAccountSigners(contract, expectation.expect as ExSubAccountSigners)
    case "ExSubAccountMarginType":
      return expectSubAccountMarginType(contract, expectation.expect as ExSubAccountMarginType)
    default:
      console.log(`🚨 Unknown expectation - add the expectation in your test: ${expectation.name} 🚨 `)
  }
}

async function expectNumAccounts(contract: Contract, expectations: ExNumAccounts) {
  const exists = await contract.accountExists(expectations.account_ids)
  expect(exists).to.be.true
}

async function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSignerPermission(expectations.address, signer)
    expect(actualPermission).to.equal(parseInt(expectedPermission, 10))
  }
}

async function expectAccountMultisigThreshold(contract: Contract, expectations: ExAccountMultiSigThreshold) {
  let [, actualMultisigThreshold, ,] = await contract.getAccountResult(expectations.address)
  expect(actualMultisigThreshold).to.equal(expectations.multi_sig_threshold)
}

async function expectSessionKeys(contract: Contract, expectations: ExSessionKeys) {
  for (var signer in expectations.signers) {
    let expectedSessionKey = expectations.signers[signer]
    let [actualSessionKey, authorizationExpiry] = await contract.getSessionKey(signer)
    expect(actualSessionKey).to.equal(expectedSessionKey)
    expect(authorizationExpiry).to.equal(parseInt(expectations.signers[signer], 10))
    expect(expectations.signers[signer]).to.not.be.empty
  }
}

async function expectWithdrawalAddresses(contract: Contract, expectations: ExAccountWithdrawalAddresses) {
  for (let i = 0; i < expectations.withdrawal_addresses.length; i++) {
    let isWithdrawalAddress = await contract.isOnboardedWithdrawalAddress(
      expectations.address,
      expectations.withdrawal_addresses[i]
    )
    expect(isWithdrawalAddress).to.equal(true)
  }
}

async function expectConfig2D(contract: Contract, expectations: ExConfig2D) {
  const val = await contract.getConfig2D(expectations.key, expectations.sub_key)
  expect(val).to.equal(expectations.value)
}

async function expectConfig1D(contract: Contract, expectations: ExConfig1D) {
  const val = await contract.getConfig1D(expectations.key)
  expect(val).to.equal(expectations.value)
}

async function expectConfigSchedule(contract: Contract, expectations: ExConfigSchedule) {
  const lockEndTime = await contract.getConfig1D(expectations.key)
  expect(lockEndTime).to.equal(Number(expectations.value))
}

async function expectConfigScheduleAbsent(contract: Contract, expectations: ExConfigScheduleAbsent) {
  const isAbsent = await contract.isConfigScheduleAbsent(expectations.key)
  expect(isAbsent).to.be.true
}

async function expectSubAccountSigners(contract: Contract, expectations: ExSubAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSignerPermission(expectations.sub_account_id, signer)
    expect(actualPermission).to.equal(parseInt(expectedPermission, 10))
  }
}

async function expectSubAccountMarginType(contract: Contract, expectations: ExSubAccountMarginType) {
  let res = await getSubAccountResult(contract, expectations.sub_account_id)
  expect(res.marginType).to.equal(parseInt(expectations.margin_type, 10))
}

export async function getAccountResult(
  contract: Contract,
  address: string
): Promise<{ id: string; multisigThreshold: number; subAccounts: any[]; adminCount: number }> {
  let [id, multisigThreshold, adminCount, subAccounts] = await contract.getAccountResult(address)
  return {
    id: id,
    multisigThreshold: multisigThreshold.toNumber(),
    subAccounts: subAccounts,
    adminCount: adminCount.toNumber(),
  }
}

export async function getSubAccountResult(
  contract: Contract,
  subAccountId: string
): Promise<{
  id: number
  adminCount: number
  signerCount: number
  accountID: string
  marginType: number
  quoteCurrency: number
  lastAppliedFundingTimestamp: number
}> {
  let [id, adminCount, signerCount, accountID, marginType, quoteCurrency, lastAppliedFundingTimestamp] =
    await contract.getSubAccountResult(subAccountId)
  return {
    id: id.toNumber(),
    adminCount: signerCount.toNumber(),
    signerCount: adminCount,
    accountID: accountID,
    marginType: marginType.toNumber(),
    quoteCurrency: quoteCurrency.toNumber(),
    lastAppliedFundingTimestamp: lastAppliedFundingTimestamp.toNumber(),
  }
}
