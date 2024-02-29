import * as hre from "hardhat"
import { getProvider, getWallet } from "./utils"
import { ethers } from "ethers"
import { ContractName } from "./contract"
import { hexlify } from "ethers/lib/utils"
import { expectToThrowAsync, nonce } from "../test/util"
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
const CONTRACT_ADDRESS = "0x4B5DF730c2e6b28E17013A1485E5d9BC41Efe021"
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

  // Run contract read function
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
    "0x86db00e10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000084a0341467ab234c8c85feb55a6b86c9c09568a400000000000000000000000084a0341467ab234c8c85feb55a6b86c9c09568a4804ff7e16693fc15c1b36790c009cc4bc2dde78efcf2a213ba6553280ab4ba69628852ccb0d6baf76d34106c9ad0717f4832b5a5e117c390adce05a465938780000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000000000000000004d200000000000000000000000000000000000000000000000000000000000004d2"

  const createAccountEncodedTxDataTwo =
    "0x86db00e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084a0341467ab234c8c85feb55a6b86c9c09568a400000000000000000000000084a0341467ab234c8c85feb55a6b86c9c09568a4804ff7e16693fc15c1b36790c009cc4bc2dde78efcf2a213ba6553280ab4ba69628852ccb0d6baf76d34106c9ad0717f4832b5a5e117c390adce05a465938780000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000000000000000004d200000000000000000000000000000000000000000000000000000000000004d2"

  var txData = [createAccountEncodedTxData, createAccountEncodedTxDataTwo]

  for (var i = 0; i < txData.length; i++) {
    var tx1 = {
      to: CONTRACT_ADDRESS,
      gasLimit: 2100000,
      data: createAccountEncodedTxData,
    }
    w1 = w1.connect(getProvider())
    const resp = await w1.sendTransaction(tx1)
    // if (i == 0) {
    await resp.wait()
    // } else {
    //   await expectToThrowAsync(resp.wait())
    // }
    console.log("Transaction " + i + " completed")
  }

  // console.log("First transaction")
  // var tx1 = {
  //   to: CONTRACT_ADDRESS,
  //   gasLimit: 2100000,
  //   data: createAccountEncodedTxData,
  // }

  // w1 = w1.connect(getProvider())
  // const resp = await w1.sendTransaction(tx1)
  // await resp.wait()

  // console.log("Second transaction")

  // var tx2 = {
  //   to: CONTRACT_ADDRESS,
  //   gasLimit: 2100000,
  //   data: createAccountEncodedTxDataTwo,
  // }

  // w1 = w1.connect(getProvider())
  // const respTwo = await w1.sendTransaction(tx2)
  // await expectToThrowAsync(respTwo.wait())
}
