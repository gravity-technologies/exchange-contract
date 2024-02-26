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

  const txData =
    "0x86db00e10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc04900000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc049ee6fc60636e2774f6caf3d68efb997760574dad4574d4ed88e76a52a047f043e01c4f8d59a90151bf10fbc038110fdf7a758fa6b64080248dfb5915f1359ca88000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000017ba7075f4bc73000000000000000000000000000000000000000000000000000000000000fb59e7"

  const txData2 =
    "0x86db00e10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc04900000000000000000000000036615cf349d7f6344891b1e7ca7c72883f5dc0493054d5cc36c9fb2e39677d6f7cd60f3a56f4a90dc1d0c8f1adc80b23028e5cde43f3c4b5e127bb8cb6cb1148ce6a274ebbd8515d7d36ad2af29fa2619a3859df000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000017ba7087c4f7e20000000000000000000000000000000000000000000000000000000000003707bc"
  // const data2 = contract.interface.encodeFunctionData("setGreeting", ["hey hey hey"])
  // console.log(data2)

  console.log(w1.address)

  const salt = nonce()
  const sig2 = genCreateAccountSig(w1, w1.address, salt)

  const sig: Signature = {
    signer: sig2.signer,
    r: hexlify(sig2.r),
    s: hexlify(sig2.s),
    v: sig2.v,
    expiration: sig2.expiration,
    nonce: sig2.nonce,
  }
  console.log("sig", sig)

  // const encodedSig = ethers.utils.defaultAbiCoder.encode(
  //   ["address", "bytes32", "bytes32", "uint8", "int64", "uint32"],
  //   [sig2.signer, sig2.r, sig2.s, sig2.v, sig2.expiration, sig2.nonce]
  // )
  // console.log("encodedSig", encodedSig)
  console.log("sig here1")
  const data2 = contract.interface.encodeFunctionData("createAccount", [1, 1, w1.address, sig])

  console.log("data2", data2)
  console.log("txData", txData)
  console.log("sig here2")
  var tx = {
    // type: utils.EIP712_TX_TYPE,
    to: CONTRACT_ADDRESS,
    gasLimit: 2100000,
    data: txData2,
  }

  w1 = w1.connect(getProvider())
  const resp = await w1.sendTransaction(tx)
  // console.log("data2", data2)
  // console.log("txData", txData)
  // console.log("Are requal", data2 === txData)
  // console.log("waiting")
  await resp.wait()
  // Read message after transaction
  // console.log(`The message now is: ${await contract.greet()}`)
}
