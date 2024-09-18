import { Wallet } from "ethers"
import { domain, EIP712Domain, PrimaryType } from "./schema"

function getRegisterWalletMessage(address: string, nonce: number) {
  return `Welcome to GRVT!

Click to sign in and accept the GRVT Terms of Service and Privacy Policy.

This request will not trigger a blockchain transaction or cost any gas fees.

Wallet address:
${address}

Nonce:
${nonce}`
}

export async function signRegisterWalletMessage(privateKey: string, address: string, nonce: number): Promise<string> {
  // Create a wallet instance from the private key
  const wallet = new Wallet(privateKey)
  console.log(wallet)

  // Sign the message
  const signature = await wallet.signMessage(getRegisterWalletMessage(address, nonce))
  console.log(signature)

  return signature
}
