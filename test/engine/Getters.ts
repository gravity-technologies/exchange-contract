import { BigNumber, Contract, ethers, utils } from "ethers"
import {
  ExAccountMultiSigThreshold,
  ExAccountSigners,
  ExAccountWithdrawalAddresses,
  ExConfig1D,
  ExConfig2D,
  ExConfigSchedule,
  ExConfigScheduleAbsent,
  ExFundingIndex,
  ExFundingTime,
  ExInterestRate,
  ExMarkPrice,
  ExNumAccounts,
  ExSessionKeys,
  ExSubAccountSigners,
  ExSubAccountMarginType,
  Expectation,
  ExSubAccountValue,
  ExSubAccountPosition,
  ExSubAccountSpot,
} from "./TestEngineTypes"
import { expect } from "chai"
import { hex32, toAssetID } from "./util"
import { ConfigIDToEnum, CurrencyToEnum } from "./enums"

export async function validateExpectation(contract: Contract, expectation: Expectation) {
  switch (expectation.name) {
    case "ExAccountSigners":
      return expectAccountSigners(contract, expectation.expect as ExAccountSigners)
    case "ExNumAccounts":
      return expectNumAccounts(contract, expectation.expect as ExNumAccounts)
    case "ExSessionKeys":
      return expectSessionKeys(contract, expectation.expect as ExSessionKeys)
    case "ExAccountMultiSigThreshold":
      return expectAccountMultisigThreshold(contract, expectation.expect as ExAccountMultiSigThreshold)
    case "ExAccountWithdrawalAddresses":
      return expectWithdrawalAddresses(contract, expectation.expect as ExAccountWithdrawalAddresses)
    case "ExConfig2D":
      return expectConfig2D(contract, expectation.expect as ExConfig2D)
    case "ExConfig":
      return expectConfig1D(contract, expectation.expect as ExConfig1D)
    case "ExConfigSchedule":
      return expectConfigSchedule(contract, expectation.expect as ExConfigSchedule)
    case "ExConfigScheduleAbsent":
      return expectConfigScheduleAbsent(contract, expectation.expect as ExConfigScheduleAbsent)
    case "ExSubAccountSigners":
      return expectSubAccountSigners(contract, expectation.expect as ExSubAccountSigners)
    case "ExSubAccountMarginType":
      return expectSubAccountMarginType(contract, expectation.expect as ExSubAccountMarginType)
    case "ExFundingIndex":
      return expectFundingIndex(contract, expectation.expect as ExFundingIndex)
    case "ExMarkPrice":
      return expectMarkPrice(contract, expectation.expect as ExMarkPrice)
    case "ExInterestRate":
      return expectInterestRate(contract, expectation.expect as ExInterestRate)
    case "ExFundingTime":
      return expectFundingTime(contract, expectation.expect as ExFundingTime)
    case "ExSubAccountValue":
      return expectSubAccountValue(contract, expectation.expect as ExSubAccountValue)
    case "ExSubAccountPosition":
      return expectSubAccountPosition(contract, expectation.expect as ExSubAccountPosition)
    case "ExSubAccountSpot":
      return expectSubAccountSpot(contract, expectation.expect as ExSubAccountSpot)
    default:
      console.log(`🚨 Unknown expectation - add the expectation in your test: ${expectation.name} 🚨 `)
  }
}

async function expectNumAccounts(contract: Contract, expectations: ExNumAccounts) {
  const exists = await contract.isAllAccountExists(expectations.account_ids)
  expect(exists).to.be.true
}

async function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSignerPermission(expectations.address, signer)
    expect(actualPermission).to.equal(parseInt(expectedPermission, 10))
  }
}

async function expectAccountMultisigThreshold(contract: Contract, expectations: ExAccountMultiSigThreshold) {
  let [, actualMultisigThreshold, ,] = await contract.getAccountResult(expectations.address)
  expect(actualMultisigThreshold).to.equal(expectations.multi_sig_threshold)
}

async function expectSessionKeys(contract: Contract, expectations: ExSessionKeys) {
  for (var sessionKey in expectations.signers) {
    expect(expectations.signers[sessionKey]).to.not.be.empty
    let [actualSubAccSigner, actualAuthorizationExpiry] = await contract.getSessionValue(
      expectations.signers[sessionKey].session_key
    )
    expect(actualSubAccSigner.toLowerCase()).to.equal(expectations.signers[sessionKey].main_signing_key.toLowerCase())
    const expectedAuthExpiry = BigNumber.from(expectations.signers[sessionKey].authorization_expiry).toNumber()
    const actualAuthExpiry = BigNumber.from(actualAuthorizationExpiry).toNumber()
    expect(actualAuthExpiry).to.equal(expectedAuthExpiry)
  }
}

async function expectWithdrawalAddresses(contract: Contract, expectations: ExAccountWithdrawalAddresses) {
  for (let i = 0; i < expectations.withdrawal_addresses.length; i++) {
    let isWithdrawalAddress = await contract.isOnboardedWithdrawalAddress(
      expectations.address,
      expectations.withdrawal_addresses[i]
    )
    expect(isWithdrawalAddress).to.equal(true)
  }
}

async function expectConfig2D(contract: Contract, expectations: ExConfig2D) {
  console.log("expectConfig2D", expectations.key, ConfigIDToEnum[expectations.key])
  console.log(convertBigEndianToLittleEndian(expectations.sub_key))
  console.log(convertBigEndianToLittleEndian(expectations.value))
  let subKey = ""
  if (isEthereumAddress(expectations.sub_key)) {
    subKey = expectations.sub_key
  } else {
    subKey = convertBigEndianToLittleEndian(expectations.sub_key)
  }
  const val = await contract.getConfig2D(ConfigIDToEnum[expectations.key], hex32(subKey))
  expect(hex32(val)).to.equal(hex32(convertBigEndianToLittleEndian(expectations.value)))
}

const isEthereumAddress = (address: string): boolean => {
  try {
    ethers.utils.getAddress(address)
    return true
  } catch (error) {
    return false
  }
}

// Function to convert big-endian hex string with '0x' prefix to little-endian hex string
function convertBigEndianToLittleEndian(bigEndianHex: string): string {
  // Remove the '0x' prefix if present
  const hexWithoutPrefix = bigEndianHex.startsWith("0x") ? bigEndianHex.slice(2) : bigEndianHex

  // Split the hex string into pairs of characters
  const pairs: string[] = hexWithoutPrefix.match(/.{1,2}/g) || []

  // Reverse the order of the pairs
  const reversedPairs: string[] = pairs.reverse()

  // Join the reversed pairs and prepend '0x' if necessary
  const littleEndianHex = reversedPairs.join("")
  return bigEndianHex.startsWith("0x") ? "0x" + littleEndianHex : littleEndianHex
}

async function expectConfig1D(contract: Contract, expectations: ExConfig1D) {
  console.log("expectConfig1D", expectations.key, ConfigIDToEnum[expectations.key])
  const [val, isSet] = await contract.getConfig1D(ConfigIDToEnum[expectations.key])
  if (isSet) {
    expect(hex32(val)).to.equal(hex32(convertBigEndianToLittleEndian(expectations.value)))
  }
}

async function expectConfigSchedule(contract: Contract, expectations: ExConfigSchedule) {
  const lockEndTime = await contract.getConfig1D(ConfigIDToEnum[expectations.key])
  expect(lockEndTime).to.equal(Number(expectations.value))
}

async function expectConfigScheduleAbsent(contract: Contract, expectations: ExConfigScheduleAbsent) {
  const isAbsent = await contract.isConfigScheduleAbsent(expectations.key)
  expect(isAbsent).to.be.true
}

async function expectSubAccountSigners(contract: Contract, expectations: ExSubAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSubAccSignerPermission(BigInt(expectations.sub_account_id), signer)
    expect(actualPermission).to.equal(parseInt(expectedPermission, 10))
  }
}

async function expectSubAccountMarginType(contract: Contract, expectations: ExSubAccountMarginType) {
  let res = await getSubAccountResult(contract, expectations.sub_account_id)
  expect(res.marginType).to.equal(parseInt(expectations.margin_type, 10))
}

async function expectFundingIndex(contract: Contract, expectations: ExFundingIndex) {
  const assetID = toAssetID(expectations.asset_dto)
  const fundingIndex = await contract.getFundingIndex(assetID)
  expect(BigInt(fundingIndex)).to.equal(BigInt(expectations.funding_rate ?? "0"))
}

async function expectFundingTime(contract: Contract, expectations: ExFundingTime) {
  const fundingTime = await contract.getFundingTime()
  expect(fundingTime).to.equal(Number(expectations.funding_time))
}

async function expectMarkPrice(contract: Contract, expectations: ExMarkPrice) {
  const assetID = toAssetID(expectations.asset_dto)
  let expectMark = BigInt(expectations.mark_price ?? "0")
  let [markPrice, found] = await contract.getMarkPrice(assetID)
  expect(BigInt(markPrice)).to.equal(expectMark)
}

async function expectInterestRate(contract: Contract, expectations: ExInterestRate) {
  const assetID = toAssetID(expectations.asset_dto)
  let expectInterest = BigInt(expectations.interest_rate ?? "0")
  let interestRate = await contract.getInterestRate(assetID)
  expect(interestRate).to.equal(expectInterest)
}

export async function getAccountResult(
  contract: Contract,
  address: string
): Promise<{ id: string; multisigThreshold: number; subAccounts: any[]; adminCount: number }> {
  let [id, multisigThreshold, adminCount, subAccounts] = await contract.getAccountResult(address)
  return {
    id: id,
    multisigThreshold: multisigThreshold.toNumber(),
    subAccounts: subAccounts,
    adminCount: adminCount.toNumber(),
  }
}

export async function getSubAccountResult(
  contract: Contract,
  subAccountId: string
): Promise<{
  id: number
  adminCount: number
  signerCount: number
  accountID: string
  marginType: number
  quoteCurrency: number
  lastAppliedFundingTimestamp: number
}> {
  let [id, adminCount, signerCount, accountID, marginType, quoteCurrency, lastAppliedFundingTimestamp] =
    await contract.getSubAccountResult(BigInt(subAccountId))
  return {
    id: id.toNumber(),
    adminCount: signerCount.toNumber(),
    signerCount: adminCount,
    accountID: accountID,
    marginType: marginType,
    quoteCurrency: quoteCurrency,
    lastAppliedFundingTimestamp: lastAppliedFundingTimestamp.toNumber(),
  }
}

async function expectSubAccountValue(contract: Contract, expectations: ExSubAccountValue) {
  const value = await contract.getSubAccountValue(BigInt(expectations.sub_account_id))
  expect(BigInt(value)).to.equal(BigInt(expectations.value))
}

async function expectSubAccountPosition(contract: Contract, expectations: ExSubAccountPosition) {
  const [balance, lastAppliedFundingIndex] = await contract.getSubAccountPosition(
    BigInt(expectations.sub_account_id),
    toAssetID(expectations.asset)
  )
  const expected = expectations.position
  expect(BigInt(balance)).to.equal(BigInt(expected.balance))
  console.log("Compare POS", expected.balance.toString(), balance.toString())
  expect(BigInt(lastAppliedFundingIndex)).to.equal(BigInt(expected.last_applied_funding_index))
}

async function expectSubAccountSpot(contract: Contract, expectations: ExSubAccountSpot) {
  const balance = await contract.getSubAccountSpotBalance(
    BigInt(expectations.sub_account_id),
    CurrencyToEnum[expectations.currency]
  )
  expect(BigInt(balance)).to.equal(BigInt(expectations.balance))
}
