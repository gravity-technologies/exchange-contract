import { Contract } from "ethers"
import { ExAccountSigners, Expectation } from "./TestEngineTypes"
import { expect } from "chai"

export function validateExpectation(contract: Contract, expectation: Expectation) {
  switch (expectation.name) {
    case "ExAccountSigners":
      return expectAccountSigners(contract, expectation.expect as ExAccountSigners)
    default:
      console.log(`Unknown expectation: ${expectation.name}`)
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
