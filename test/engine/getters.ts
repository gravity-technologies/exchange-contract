import { Contract } from "ethers"
import { ExAccountSigners } from "./TestEngineTypes"

export function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    const permission = expectations.signers[signer]
    let perm = contract.getSignerPermission(expectations.address, signer)
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
