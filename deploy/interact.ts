import * as hre from "hardhat"
import { getWallet, getProvider } from "./utils"
import { ethers } from "ethers"
import { ContractName } from "./contract"
import { hexlify } from "ethers/lib/utils"
import { nonce } from "../test/util"
import { genCreateAccountSig } from "../test/signature"

interface Signature {
  signer: string
  r: string
  s: string
  v: number
  expiration: BigInt
  nonce: number
}

// Address of the contract to interact with
const CONTRACT_ADDRESS = "0x111C3E89Ce80e62EE88318C2804920D4c96f92bb"
if (!CONTRACT_ADDRESS) throw "⛔️ Provide address of the contract to interact with!"

// An example of a script to interact with the contract
export default async function () {
  var w1 = getWallet()
  console.log(`Running script to interact with contract ${CONTRACT_ADDRESS}`)

  // Load compiled contract info
  const contractArtifact = await hre.artifacts.readArtifact(ContractName)

  // Initialize contract instance for interaction
  const contract = new ethers.Contract(
    CONTRACT_ADDRESS,
    contractArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  )

  const salt = nonce()
  const signedSig = genCreateAccountSig(w1, w1.address, salt)

  const sig: Signature = {
    signer: signedSig.signer,
    r: hexlify(signedSig.r),
    s: hexlify(signedSig.s),
    v: signedSig.v,
    expiration: signedSig.expiration,
    nonce: signedSig.nonce,
  }

  // Code to show how to encode function data
  // const txData = contract.interface.encodeFunctionData("createAccount", [1, 1, w1.address, sig])
  const createAccountEncodedTxData =
    "0x86db00e10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc04900000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc0493054d5cc36c9fb2e39677d6f7cd60f3a56f4a90dc1d0c8f1adc80b23028e5cde43f3c4b5e127bb8cb6cb1148ce6a274ebbd8515d7d36ad2af29fa2619a3859df000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000017ba7087c4f7e20000000000000000000000000000000000000000000000000000000000003707bc"

  var tx = {
    to: CONTRACT_ADDRESS,
    gasLimit: 2100000,
    data: createAccountEncodedTxData,
  }

  w1 = w1.connect(getProvider())
  const resp = await w1.sendTransaction(tx)
  await resp.wait()
}
