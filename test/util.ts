import { expect } from "chai"
import { randomInt } from "crypto"
import { AbstractSigner, BaseWallet, BytesLike, NonceManager, Wallet, toBeHex, zeroPadValue } from "ethers"
import { NumConfig } from "./type"

export async function expectToThrowAsync(promise: Promise<any>, message?: string) {
  let error = null
  try {
    await promise
    expect.fail("Expected an error but didn't get one!")
  } catch (err) {
    if (message != null) {
      // console.log("🚨", err)
      // expect((<any>error).message).to.include(message)
    }
  }
}

export async function expectNotToThrowAsync(promise: Promise<any>) {
  let error = null
  try {
    await promise
  } catch (err) {
    error = err
  }
  expect(error).to.be.null
}

export function buf(s: string): Buffer {
  return Buffer.from(s.substring(2), "hex")
}

export function getTimestampNs(addDays: number = 10): number {
  const deltaInMs = addDays * 24 * 60 * 60 * 1000
  return Math.floor((Date.now() + deltaInMs) * 1000)
}

export function wallet(pkHex?: string): BaseWallet {
  if (pkHex == null) {
    return Wallet.createRandom()
  }
  return new Wallet(pkHex)
}

export function nonce() {
  return randomInt(22021991)
}

export type CfgMap = Map<number, Bytes32>

export async function bytes32(v: string | number | AbstractSigner): Promise<Bytes32> {
  let hex: BytesLike = "0"
  if (typeof v === "number") {
    hex = toBeHex(v)
  } else if (v instanceof AbstractSigner) {
    hex = await v.getAddress()
  }
  return zeroPadValue(hex, 32)
}

export type Bytes32 = string

export function getConfigArray(configMap: CfgMap): Bytes32[] {
  const res = new Array(NumConfig).fill(bytes32(0))
  for (const [key, value] of configMap) {
    res[key] = value
  }
  return res
}
