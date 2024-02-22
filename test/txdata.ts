import { Contract } from "ethers"

async function processRawTransaction(contract: Contract, data: string) {
  var provider = contract.provider
  var tx = {
    to: contract.address,
    value: 0,
    data: data,
  }
  await provider.call(tx)
}
