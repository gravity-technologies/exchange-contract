import { Contract } from "ethers"
import { ExAccountSigners, ExAccountWithdrawalAddresses, ExSessionKeys, Expectation } from "./TestEngineTypes"
import { expect } from "chai"

export function validateExpectation(contract: Contract, expectation: Expectation) {
  switch (expectation.name) {
    case "ExAccountSigners":
      return expectAccountSigners(contract, expectation.expect as ExAccountSigners)
    case "ExSessionKeys":
      return expectSessionKeys(contract, expectation.expect as ExSessionKeys)
    case "ExWithdrawalAddresses":
      return expectWithdrawalAddresses(contract, expectation.expect as ExAccountWithdrawalAddresses)
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

async function expectWithdrawalAddresses(contract: Contract, expectations: ExAccountWithdrawalAddresses) {
  for (let i = 0; i < expectations.withdrawal_addresses.length; i++) {
    let isWithdrawalAddress = await contract.isOnboardedWithdrawalAddress(
      expectations.address,
      expectations.withdrawal_addresses[i]
    )
    expect(isWithdrawalAddress).to.equal(true)
  }
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
