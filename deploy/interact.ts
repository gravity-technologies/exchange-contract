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
const CONTRACT_ADDRESS = "0x26b368C3Ed16313eBd6660b72d8e4439a697Cb0B"
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
  // sig stuct that can be encoded
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
    "0x86db00e1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000003537f67f63f16951b7168e7c641a0013030614240000000000000000000000003537f67f63f16951b7168e7c641a0013030614248eb9833d6fcedb7424159f13e39458a2327b01c7e14a19b0db6c68d40757cd2b2e7df13b6a0b8a1557b44f7cb81cf725a51efc787eb2ffe179366b99f342eea4000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000000000000000004d200000000000000000000000000000000000000000000000000000000000004d2"

  var tx = {
    to: CONTRACT_ADDRESS,
    gasLimit: 2100000,
    data: createAccountEncodedTxData,
  }

  w1 = w1.connect(getProvider())
  const resp = await w1.sendTransaction(tx)
  await resp.wait()
}
