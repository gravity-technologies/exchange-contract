import { expect } from "chai"
import { BigNumber, Contract, ethers } from "ethers"
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
  ExSettlementPrice,
  ExSubAccountMarginType,
  ExSubAccountPosition,
  ExSubAccountSigners,
  ExSubAccountSpot,
  ExSubAccountValue,
  ExAccountRecoveryAddresses,
  ExNotAccountRecoveryAddresses,
  ExAccountSpot,
  ExConfigNotSet,
  ExConfig2DNotSet,
  ExSimpleCrossMaintenanceMarginTiers,
  ExSimpleCrossMaintenanceMarginTimelockEndTime,
  ExSimpleCrossMaintenanceMarginTiersNoTimelock,
  ExSubAccountMaintMargin,
  ExOnboardedTransferAccount,
  Expectation,
} from "./types"
import { ConfigIDToEnum, CurrencyToEnum } from "./enums"
import { hex32, toAssetID } from "./util"

// These expectations are only in risk
const ignoredExpectations = new Set(["ExSubAccountInitMargin", "ExSubAccountAPI"])

export async function validateExpectations(contract: Contract, expectations: Expectation[]) {
  for (let expectation of expectations ?? []) {
    await validateExpectation(contract, expectation)
  }
}

export async function validateExpectation(contract: Contract, expectation: Expectation) {
  if (ignoredExpectations.has(expectation.name)) {
    return
  }
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
    case "ExSettlementPrice":
      return expectSettlementPrice(contract, expectation.expect as ExSettlementPrice)
    case "ExAccountRecoveryAddresses":
      return expectAccountRecoveryAddresses(contract, expectation.expect as ExAccountRecoveryAddresses)
    case "ExNotAccountRecoveryAddresses":
      return expectNotAccountRecoveryAddresses(contract, expectation.expect as ExNotAccountRecoveryAddresses)
    case "ExAccountSpot":
      return expectAccountSpot(contract, expectation.expect as ExAccountSpot)
    case "ExConfigNotSet":
      return expectConfigNotSet(contract, expectation.expect as ExConfigNotSet)
    case "ExConfig2DNotSet":
      return expectConfig2DNotSet(contract, expectation.expect as ExConfig2DNotSet)
    case "ExSimpleCrossMaintenanceMarginTiers":
      return expectSimpleCrossMaintenanceMarginTiers(
        contract,
        expectation.expect as ExSimpleCrossMaintenanceMarginTiers
      )
    case "ExSimpleCrossMaintenanceMarginTimelockEndTime":
      return expectSimpleCrossMaintenanceMarginTimelockEndTime(
        contract,
        expectation.expect as ExSimpleCrossMaintenanceMarginTimelockEndTime
      )
    case "ExSimpleCrossMaintenanceMarginTiersNoTimelock":
      return expectSimpleCrossMaintenanceMarginTiersNoTimelock(
        contract,
        expectation.expect as ExSimpleCrossMaintenanceMarginTiersNoTimelock
      )
    case "ExSubAccountMaintMargin":
      return expectSubAccountMaintenanceMargin(contract, expectation.expect as ExSubAccountMaintMargin)
    case "ExOnboardedTransferAccount":
      return expectOnboardedTransferAccount(contract, expectation.expect as ExOnboardedTransferAccount)
    default:
      console.log(`🚨 Unknown expectation - add the expectation in your test: ${expectation.name} 🚨 `)
  }
}

async function expectNumAccounts(contract: Contract, expectations: ExNumAccounts) {
  const exists = await contract.isAllAccountExists(expectations.account_ids ?? [])
  expect(exists).to.be.true
}

async function expectAccountSigners(contract: Contract, expectations: ExAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSignerPermission(expectations.address, signer)
    expect(big(actualPermission)).to.equal(big(expectedPermission))
  }
}

async function expectAccountMultisigThreshold(contract: Contract, expectations: ExAccountMultiSigThreshold) {
  let [, actualMultisigThreshold, ,] = await contract.getAccountResult(expectations.address)
  expect(big(actualMultisigThreshold)).to.equal(big(expectations.multi_sig_threshold))
}

async function expectSessionKeys(contract: Contract, expectations: ExSessionKeys) {
  for (var sessionKey in expectations.signers) {
    expect(expectations.signers[sessionKey]).to.not.be.empty
    let [actualSubAccSigner, actualAuthorizationExpiry] = await contract.getSessionValue(
      expectations.signers[sessionKey].session_key
    )
    expect(actualSubAccSigner.toLowerCase()).to.equal(expectations.signers[sessionKey].main_signing_key.toLowerCase())
    const expectedAuthExpiry = expectations.signers[sessionKey].authorization_expiry
    const actualAuthExpiry = actualAuthorizationExpiry
    expect(big(actualAuthExpiry)).to.equal(big(expectedAuthExpiry))
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
  let subKey = big(expectations.sub_key)
  let subKeyHex = ethers.utils.hexZeroPad(subKey.toHexString(), 32)
  const val = await contract.getConfig2D(ConfigIDToEnum[expectations.key], subKeyHex)
  expect(big(val)).to.equal(big(expectations.value))
}

async function expectConfig1D(contract: Contract, expectations: ExConfig1D) {
  const key = ConfigIDToEnum[expectations.key]
  expect(key).to.not.be.null
  const val = await contract.getConfig1D(key)
  expect(big(val)).to.equal(big(expectations.value))
}

async function expectConfigSchedule(contract: Contract, expectations: ExConfigSchedule) {
  const lockEndTime = await contract.getConfigSchedule(ConfigIDToEnum[expectations.key], hex32(expectations.sub_key))
  expect(big(lockEndTime)).to.equal(big(expectations.lock_end))
}

async function expectConfigScheduleAbsent(contract: Contract, expectations: ExConfigScheduleAbsent) {
  const key = ConfigIDToEnum[expectations.key]
  const isAbsent = await contract.isConfigScheduleAbsent(key, hex32(expectations.sub_key))
  expect(isAbsent).to.be.true
}

async function expectSubAccountSigners(contract: Contract, expectations: ExSubAccountSigners) {
  for (var signer in expectations.signers) {
    let expectedPermission = expectations.signers[signer]
    let actualPermission = await contract.getSubAccSignerPermission(BigInt(expectations.sub_account_id), signer)
    expect(big(actualPermission)).to.equal(big(expectedPermission))
  }
}

async function expectSubAccountMarginType(contract: Contract, expectations: ExSubAccountMarginType) {
  let res = await getSubAccountResult(contract, expectations.sub_account_id)
  expect(big(res.marginType)).to.equal(big(expectations.margin_type))
}

async function expectFundingIndex(contract: Contract, expectations: ExFundingIndex) {
  let assetID = big(toAssetID(expectations.asset_dto))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  const fundingIndex = await contract.getFundingIndex(assetIDHex)
  expect(big(fundingIndex)).to.equal(big(expectations.funding_rate ?? "0"))
}

async function expectFundingTime(contract: Contract, expectations: ExFundingTime) {
  const fundingTime = await contract.getFundingTime()
  const stateTimestamp = await contract.getTimestamp()
  expect(big(fundingTime).sub(big(stateTimestamp))).to.equal(big(expectations.funding_time_delta))
}

async function expectMarkPrice(contract: Contract, expectations: ExMarkPrice) {
  // const assetID = toAssetID(expectations.asset_dto)
  let assetID = big(toAssetID(expectations.asset_dto))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  let expectMark = BigInt(expectations.mark_price ?? "0")
  let [markPrice, found] = await contract.getMarkPrice(assetIDHex)
  expect(big(markPrice)).to.equal(big(expectMark))
}

async function expectInterestRate(contract: Contract, expectations: ExInterestRate) {
  let assetID = big(toAssetID(expectations.asset_dto))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  let expectInterest = BigInt(expectations.interest_rate ?? "0")
  let interestRate = await contract.getInterestRate(assetIDHex)
  expect(big(interestRate)).to.equal(big(expectInterest))
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
  expect(big(value)).to.equal(big(expectations.value))
  // console.log("ExTotalValue", bn(value).toNumber(), "expectations", expectations.value)
}

async function expectSubAccountPosition(contract: Contract, expectations: ExSubAccountPosition) {
  let assetID = big(toAssetID(expectations.asset))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  const expectedPos = expectations.position
  const [found, balance, lastAppliedFundingIndex] = await contract.getSubAccountPosition(
    BigInt(expectations.sub_account_id),
    assetIDHex
  )
  if (expectedPos == null) {
    expect(found).to.be.false
  } else {
    expect(big(balance)).to.equal(big(expectedPos.balance ?? "0"))
    expect(big(lastAppliedFundingIndex)).to.equal(big(expectedPos.last_applied_funding_index))
  }
  // console.log("ExPosition: OK", expectations.position)
}

async function expectSubAccountSpot(contract: Contract, expectations: ExSubAccountSpot) {
  const balance = await contract.getSubAccountSpotBalance(
    BigInt(expectations.sub_account_id),
    CurrencyToEnum[expectations.currency]
  )
  expect(big(balance)).to.equal(big(expectations.balance))
  // console.log("ExSpot: OK", bn(balance).toNumber(), expectations.balance)
}

async function expectSettlementPrice(contract: Contract, expectations: ExSettlementPrice) {
  let assetID = big(toAssetID(expectations.asset_dto))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  const [price, found] = await contract.getSettlementPrice(assetIDHex)
  if (expectations.settlement_price == null) {
    expect(found).to.be.false
  } else {
    expect(found).to.be.true
    expect(big(price)).to.equal(big(expectations.settlement_price))
  }
}

async function expectAccountRecoveryAddresses(contract: Contract, expectations: ExAccountRecoveryAddresses) {
  for (const signer in expectations.recovery_addresses) {
    const recoveryAddresses = expectations.recovery_addresses[signer]
    for (const recoveryAddress of recoveryAddresses) {
      const result = await contract.isRecoveryAddress(expectations.address, signer, recoveryAddress)
      expect(result).to.be.true
    }
  }
}

async function expectNotAccountRecoveryAddresses(contract: Contract, expectations: ExNotAccountRecoveryAddresses) {
  for (const signer in expectations.not_recovery_addresses) {
    const recoveryAddresses = expectations.not_recovery_addresses[signer]
    for (const recoveryAddress of recoveryAddresses) {
      const result = await contract.isRecoveryAddress(expectations.address, signer, recoveryAddress)
      expect(result).to.be.false
    }
  }
}

async function expectAccountSpot(contract: Contract, expectations: ExAccountSpot) {
  const balance = await contract.getAccountSpotBalance(expectations.account_id, CurrencyToEnum[expectations.currency])
  expect(big(balance)).to.equal(big(expectations.balance))
}

async function expectConfigNotSet(contract: Contract, expectations: ExConfigNotSet) {
  const isSet = await contract.config1DIsSet(ConfigIDToEnum[expectations.key])
  expect(isSet).to.be.false
}

async function expectConfig2DNotSet(contract: Contract, expectations: ExConfig2DNotSet) {
  const isSet = await contract.config2DIsSet(ConfigIDToEnum[expectations.key])
  expect(isSet).to.be.false
}
async function expectSimpleCrossMaintenanceMarginTiers(
  contract: Contract,
  expectations: ExSimpleCrossMaintenanceMarginTiers
) {
  const tiers = await contract.getSimpleCrossMaintenanceMarginTiers("0x" + expectations.kuq)
  const convertedTiers = tiers.map((tier: { bracketStart: BigNumber; rate: number }) => ({
    bracket_start: tier.bracketStart.toString(),
    rate: tier.rate,
  }))
  expect(convertedTiers).to.deep.equal(expectations.tiers)
}

async function expectSimpleCrossMaintenanceMarginTimelockEndTime(
  contract: Contract,
  expectations: ExSimpleCrossMaintenanceMarginTimelockEndTime
) {
  const timelockEndTime = await contract.getSimpleCrossMaintenanceMarginTimelockEndTime("0x" + expectations.kuq)
  const stateTimestamp = await contract.getTimestamp()
  const actualDelta = big(timelockEndTime).sub(big(stateTimestamp))
  expect(actualDelta).to.equal(big(expectations.timelock_end_time_delta))
}

async function expectSimpleCrossMaintenanceMarginTiersNoTimelock(
  contract: Contract,
  expectations: ExSimpleCrossMaintenanceMarginTiersNoTimelock
) {
  expect(await contract.getSimpleCrossMaintenanceMarginTimelockEndTime("0x" + expectations.kuq)).to.be.equal(0)
}

async function expectSubAccountMaintenanceMargin(contract: Contract, expectations: ExSubAccountMaintMargin) {
  expect(await contract.getSubAccountMaintenanceMargin(BigInt(expectations.sub_account_id))).to.be.equal(
    expectations.maint_margin
  )
}

async function expectOnboardedTransferAccount(contract: Contract, expectations: ExOnboardedTransferAccount) {
  const isOnboarded = await contract.getAccountOnboardedTransferAccount(
    expectations.account_id,
    expectations.transfer_account
  )
  expect(isOnboarded).to.be.true
}

function big(s: any): BigNumber {
  return BigNumber.from(s)
}
