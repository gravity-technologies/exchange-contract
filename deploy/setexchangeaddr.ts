import * as hre from "hardhat"
import { getProvider, getWallet } from "./utils.ts"
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
const CONTRACT_ADDRESS = "0x8cb4B4d11E73377e167b20f8c141363CD39D63a4"
if (!CONTRACT_ADDRESS) throw "⛔️ Provide address of the contract to interact with!"

const L2_SHARED_BRIDGE_ADDRESS = "0x40bbe828992b1548e4a72b43a3464f9f01c3145f"
if (!L2_SHARED_BRIDGE_ADDRESS) throw "⛔️ Provide address of the contract to interact with!"

// An example of a script to interact with the contract
export default async function () {
  try {
    await setL2SharedBridgeExchangeAddress(CONTRACT_ADDRESS, L2_SHARED_BRIDGE_ADDRESS)
  } catch (error) {}
}

export const setL2SharedBridgeExchangeAddress = async (exchangeAddress: string, l2SharedBridgeAddress: string) => {
  const abi = ["function setExchangeAddress(address _exchangeAddress) external"]

  const zkWallet = getWallet()
  const l2SharedBridge = new ethers.Contract(l2SharedBridgeAddress, abi, zkWallet)

  try {
    const tx = await l2SharedBridge.setExchangeAddress(exchangeAddress)
    console.log("setExchangeAddress transaction hash:", tx.hash)

    // Wait for the transaction to be mined
    const receipt = await tx.wait()
    console.log("Transaction was mined in block:", receipt.blockNumber)
  } catch (error) {
    console.error("Error calling setExchangeAddress:", error)
  }
}
