import { Contract } from "ethers"
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
  Expectation,
} from "./TestEngineTypes"
import { expect } from "chai"
import { toAssetID } from "./util"

export function validateExpectation(contract: Contract, expectation: Expectation) {
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
    case "ExFundingIndex":
      return expectFundingIndex(contract, expectation.expect as ExFundingIndex)
    case "ExMarkPrice":
      return expectMarkPrice(contract, expectation.expect as ExMarkPrice)
    case "ExInterestRate":
      return expectInterestRate(contract, expectation.expect as ExInterestRate)
    case "ExFundingTime":
      return expectFundingTime(contract, expectation.expect as ExFundingTime)
    default:
      console.log(`🚨 Unknown expectation - add the expectation in your test: ${expectation.name} 🚨 `)
  }
}

async function expectNumAccounts(contract: Contract, expectations: ExNumAccounts) {
  const exists = await contract.accountExists(expectations.account_ids)
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
  for (var signer in expectations.signers) {
    let expectedSessionKey = expectations.signers[signer]
    let [actualSessionKey, authorizationExpiry] = await contract.getSessionKey(signer)
    expect(actualSessionKey).to.equal(expectedSessionKey)
    expect(authorizationExpiry).to.equal(parseInt(expectations.signers[signer], 10))
    expect(expectations.signers[signer]).to.not.be.empty
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
  const val = await contract.getConfig2D(expectations.key, expectations.sub_key)
  expect(val).to.equal(expectations.value)
}

async function expectConfig1D(contract: Contract, expectations: ExConfig1D) {
  const val = await contract.getConfig1D(expectations.key)
  expect(val).to.equal(expectations.value)
}

async function expectConfigSchedule(contract: Contract, expectations: ExConfigSchedule) {
  const lockEndTime = await contract.getConfig1D(expectations.key)
  expect(lockEndTime).to.equal(Number(expectations.value))
}

async function expectConfigScheduleAbsent(contract: Contract, expectations: ExConfigScheduleAbsent) {
  const isAbsent = await contract.isConfigScheduleAbsent(expectations.key)
  expect(isAbsent).to.be.true
}

async function expectFundingIndex(contract: Contract, expectations: ExFundingIndex) {
  const assetID = toAssetID({
    Kind: expectations.asset_dto.kind,
    Underlying: expectations.asset_dto.underlying,
    Quote: expectations.asset_dto.quote,
    StrikePrice: BigInt(0),
    Expiration: BigInt(0),
  })
  const fundingIndex = await contract.getFundingIndex(assetID)
  expect(fundingIndex).to.equal(expectations.funding_rate)
}

async function expectFundingTime(contract: Contract, expectations: ExFundingTime) {
  const fundingTime = await contract.getFundingTime()
  expect(fundingTime).to.equal(Number(expectations.funding_time))
}

async function expectMarkPrice(contract: Contract, expectations: ExMarkPrice) {
  const assetID = toAssetID({
    Kind: expectations.asset_dto.kind,
    Underlying: expectations.asset_dto.underlying,
    Quote: expectations.asset_dto.quote,
    StrikePrice: BigInt(expectations.asset_dto.strike_price ?? "0"),
    Expiration: BigInt(expectations.asset_dto.expiration ?? "0"),
  })
  let expectMark = BigInt(expectations.mark_price ?? "0")
  let markPrice = await contract.getMarkPrice(assetID)
  expect(markPrice).to.equal(expectMark)
}

async function expectInterestRate(contract: Contract, expectations: ExInterestRate) {
  const assetID = toAssetID({
    Kind: expectations.asset_dto.kind,
    Underlying: expectations.asset_dto.underlying,
    Quote: expectations.asset_dto.quote,
    StrikePrice: BigInt(expectations.asset_dto.strike_price ?? "0"),
    Expiration: BigInt(expectations.asset_dto.expiration ?? "0"),
  })
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
