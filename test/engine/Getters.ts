import { Contract } from "ethers"
import {
  ExAccountSigners,
  ExConfig1D,
  ExConfig2D,
  ExConfigSchedule,
  ExConfigScheduleAbsent,
  ExSessionKeys,
  Expectation,
} from "./TestEngineTypes"
import { expect } from "chai"

export function validateExpectation(contract: Contract, expectation: Expectation) {
  switch (expectation.name) {
    case "ExAccountSigners":
      return expectAccountSigners(contract, expectation.expect as ExAccountSigners)
    case "ExSessionKeys":
      return expectSessionKeys(contract, expectation.expect as ExSessionKeys)
    case "ExConfig2D":
      return expectConfig2D(contract, expectation.expect as ExConfig2D)
    case "ExConfig":
      return expectConfig1D(contract, expectation.expect as ExConfig1D)
    case "ExConfigSchedule":
      return expectConfigSchedule(contract, expectation.expect as ExConfigSchedule)
    case "ExConfigScheduleAbsent":
      return expectConfigScheduleAbsent(contract, expectation.expect as ExConfigScheduleAbsent)
    default:
      console.log(`🚨 Unknown expectation - add the expectation in your test: ${expectation.name} 🚨 `)
  }
}

async function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let expectedMultisigThreshold = expectations.multi_sig_threshold
    let actualPermission = await contract.getSignerPermission(expectations.address, signer)
    let [, actualMultisigThreshold, ,] = await contract.getAccountResult(expectations.address)
    expect(actualPermission).to.equal(parseInt(expectedPermission, 10))
    expect(actualMultisigThreshold).to.equal(expectedMultisigThreshold)
  }
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
