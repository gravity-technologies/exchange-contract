import { utils } from "ethers"
import { Asset } from "./types"
import { CurrencyToEnum, KindToEnum } from "./enums"
import { TestCase } from "./types"
import * as fs from "fs"

function getLSB(val: bigint, shift: number) {
  return Number((val >> BigInt(shift)) & BigInt(0xff))
}

export const toAssetID = ({ kind, underlying, quote, expiration, strike_price }: Asset) => {
  let msg = new Uint8Array()
  const k = KindToEnum[kind ?? "UNSPECIFIED"]
  const u = CurrencyToEnum[underlying ?? "UNSPECIFIED"]
  const q = CurrencyToEnum[quote ?? "UNSPECIFIED"]
  const expiryBI = BigInt(expiration ?? 0)
  const strikeBI = BigInt(strike_price ?? 0)

  switch (kind) {
    case "SPOT":
    case "RATE":
    case "SETTLEMENT":
      msg = new Uint8Array(2)
      msg[1] = k
      msg[0] = u
    case "PERPETUAL":
      msg = new Uint8Array(3)
      msg[2] = k
      msg[1] = u
      msg[0] = q
    case "FUTURE":
      msg = new Uint8Array(12)
      msg[11] = k
      msg[10] = u
      msg[9] = q
      msg[8] = 0 // Saving a byte for future use
      msg[7] = getLSB(expiryBI, 0)
      msg[6] = getLSB(expiryBI, 8)
      msg[5] = getLSB(expiryBI, 16)
      msg[4] = getLSB(expiryBI, 24)
      msg[3] = getLSB(expiryBI, 32)
      msg[2] = getLSB(expiryBI, 40)
      msg[1] = getLSB(expiryBI, 48)
      msg[0] = getLSB(expiryBI, 56)
    case "CALL":
    case "PUT":
      msg = new Uint8Array(20)
      msg[19] = k
      msg[18] = u
      msg[17] = q
      msg[16] = 0 // Saving a byte for future use
      msg[15] = getLSB(expiryBI, 0)
      msg[14] = getLSB(expiryBI, 8)
      msg[13] = getLSB(expiryBI, 16)
      msg[12] = getLSB(expiryBI, 24)
      msg[11] = getLSB(expiryBI, 32)
      msg[10] = getLSB(expiryBI, 40)
      msg[9] = getLSB(expiryBI, 48)
      msg[8] = getLSB(expiryBI, 56)
      msg[7] = getLSB(strikeBI, 0)
      msg[6] = getLSB(strikeBI, 8)
      msg[5] = getLSB(strikeBI, 16)
      msg[4] = getLSB(strikeBI, 24)
      msg[3] = getLSB(strikeBI, 32)
      msg[2] = getLSB(strikeBI, 40)
      msg[1] = getLSB(strikeBI, 48)
      msg[0] = getLSB(strikeBI, 56)
  }
  return hex32(msg)
}

export function hex32(val: string | Uint8Array) {
  return utils.hexZeroPad(utils.hexValue(val), 32)
}

/**
 * Scale a string representing a bigint from one decimal precision to another.
 * @param {string} valueStr - The original value as a string.
 * @param {number} currentDecimals - The current number of decimals.
 * @param {number} newDecimals - The desired number of decimals.
 * @returns {string} - The scaled value as a string.
 */
export function scaleBigInt(valueStr: string, currentDecimals: number, newDecimals: number): string {
  const value = BigInt(valueStr)

  let scaledValue: bigint

  if (currentDecimals < newDecimals) {
    // Scale up by multiplying by 10^(newDecimals - currentDecimals)
    scaledValue = value * BigInt(10 ** (newDecimals - currentDecimals))
  } else if (currentDecimals > newDecimals) {
    // Scale down by dividing by 10^(currentDecimals - newDecimals)
    scaledValue = value / BigInt(10 ** (currentDecimals - newDecimals))
  } else {
    // No scaling needed
    scaledValue = value
  }

  return scaledValue.toString()
}

export function parseTestsFromFile(filePath: string): TestCase[] {
  try {
    // Read the JSON file
    const data = fs.readFileSync(filePath, "utf8")

    // Parse the JSON data into an array of Test objects
    try {
      const tests = JSON.parse(data) as TestCase[]
      return tests
    } catch (error) {
      console.error("Failed to parse JSON:", error)
      return []
    }
  } catch (err) {
    console.log(`Error reading file from disk: ${err}`)
    return []
  }
}

// Get all json files in the test fixtures directory
export function getTestFixtures(dir: string): string[] {
  return fs.readdirSync(dir).filter((file) => file.endsWith(".json"))
}
