import { Contract } from "ethers"
import { ExAccountSigners } from "./TestEngineTypes"
import { expect } from "chai"

export async function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSignerPermission(expectations.address, signer)
    expect(2 ** actualPermission).to.equal(parseInt(expectedPermission, 10))
  }
}

export async function getAccount(
  contract: Contract,
  address: string
): Promise<{ id: string; multisigThreshold: number; subAccounts: any[]; adminCount: number }> {
  let { id, multisigThreshold, subAccounts, adminCount } = await contract.getAccount(address)
  return {
    id: id,
    multisigThreshold: multisigThreshold.toNumber(),
    subAccounts: subAccounts,
    adminCount: adminCount.toNumber(),
  }
}
