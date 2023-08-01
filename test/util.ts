import { ethers } from "hardhat"
import { expect } from "chai"
import { randomInt } from "crypto"
import { Wallet } from "ethers"

export async function expectToThrowAsync(promise: Promise<any>, message?: string) {
  let error = null
  try {
    await promise
  } catch (err) {
    error = err
  }
  expect(error).to.be.an("Error")
  if (message != null) {
    // console.log(error.message)
    expect(error.message).to.include(message)
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

export function wallet(): Wallet {
  return ethers.Wallet.createRandom()
}

export function nonce() {
  return randomInt(22021991)
}
