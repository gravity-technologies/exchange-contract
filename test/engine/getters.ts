import { Contract } from "ethers"
import { ExAccountSigners } from "./TestEngineTypes"

export function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  console.log("here")
  console.log(expectations)
  console.log(expectations.signers)
  for (var signer in expectations.signers) {
    const permission = expectations.signers[signer]
    let perm = contract.getSignerPermissions(expectations.address, signer)
    console.log("hereee")
    console.log(permission)
    console.log(perm)
    console.log(expectations.signers[signer])
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
