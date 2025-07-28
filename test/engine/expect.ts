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
  ExFundingTimeDelta,
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
  ExExchangeCurrencyBalance,
  ExSubAccountSpotReal,
  ExSubAccountPositionOptional,
  ExSubAccountSummaryOptional,
  ExNumSubAccountPositions,
  ExInsuranceFundLoss,
  ExTotalClientEquity,
  ExVaultParams,
  ExVaultStatus,
  ExVaultTotalLpTokenSupply,
  ExVaultLpInfo,
  ExSubAccountUnderDeriskMargin,
  ExCurrencyConfig,
  ExCurrencyCount,
} from "./types"
import { ConfigIDToEnum, CurrencyToEnum, MarginTypeToEnum, VaultStatusToEnum } from "./enums"
import { hex32, toAssetID } from "./util"

// These expectations are only in risk
const ignoredExpectations = new Set(["ExSubAccountInitMargin", "ExSubAccountAPI", "ExpectInstrumentMinSize", "ExSubAccountSpotReal"])

export async function validateExpectations(contract: Contract, expectations: Expectation[]) {
  for (let expectation of expectations ?? []) {
    // console.log("validateExpectations", expectation)
    await validateExpectation(contract, expectation)
    // console.log("OK")
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
    case "ExFundingTimeDelta":
      return expectFundingTimeDelta(contract, expectation.expect as ExFundingTimeDelta)
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
    case "ExExchangeCurrencyBalance":
      return expectExchangeCurrencyBalance(contract, expectation.expect as ExExchangeCurrencyBalance)
    case "ExSubAccountSpotReal":
      console.log(`⚠️ ${expectation.name} is not check on contract because calculation logic is not in contract ⚠️ `)
      break
    case "ExSubAccountPositionOptional":
      return expectSubAccountPositionOptional(contract, expectation.expect as ExSubAccountPositionOptional)
    case "ExInsuranceFundLoss":
      return expectInsuranceFundLoss(contract, expectation.expect as ExInsuranceFundLoss)
    case "ExTotalClientEquity":
      return expectTotalClientEquity(contract, expectation.expect as ExTotalClientEquity)
    case "ExSubAccountSummaryOptional":
      return expectSubAccountSummaryOptional(contract, expectation.expect as ExSubAccountSummaryOptional)
    case "ExNumSubAccountPositions":
      return expectNumSubAccountPositions(contract, expectation.expect as ExNumSubAccountPositions)
    case "ExVaultParams":
      return expectVaultParams(contract, expectation.expect as ExVaultParams)
    case "ExVaultStatus":
      return expectVaultStatus(contract, expectation.expect as ExVaultStatus)
    case "ExVaultTotalLpTokenSupply":
      return expectVaultTotalLpTokenSupply(contract, expectation.expect as ExVaultTotalLpTokenSupply)
    case "ExVaultLpInfo":
      return expectVaultLpInfo(contract, expectation.expect as ExVaultLpInfo)
    case "ExSubAccountUnderDeriskMargin":
      return expectSubAccountUnderDeriskMargin(contract, expectation.expect as ExSubAccountUnderDeriskMargin)
    case "ExCurrencyConfig":
      return expectCurrencyConfig(contract, expectation.expect as ExCurrencyConfig)
    case "ExCurrencyCount":
      return expectCurrencyCount(contract, expectation.expect as ExCurrencyCount)
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
    const expectedAuthExpiry = big(await contract.getTimestamp()).add(
      big(expectations.signers[sessionKey].authorization_expiry_delta)
    )
    const actualAuthExpiry = actualAuthorizationExpiry
    expect(big(actualAuthExpiry)).to.equal(expectedAuthExpiry)
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
  const expectedLockEndTime = big(await contract.getTimestamp()).add(big(expectations.lock_end_delta))
  expect(big(lockEndTime)).to.equal(expectedLockEndTime)
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

async function expectFundingTimeDelta(contract: Contract, expectations: ExFundingTimeDelta) {
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
  id: string
  adminCount: number
  signerCount: number
  accountID: string
  marginType: number
  quoteCurrency: number
  lastAppliedFundingTimestamp: bigint
}> {
  let [id, adminCount, signerCount, accountID, marginType, quoteCurrency, lastAppliedFundingTimestamp] =
    await contract.getSubAccountResult(BigInt(subAccountId))
  return {
    id: id,
    adminCount: signerCount.toNumber(),
    signerCount: adminCount,
    accountID: accountID,
    marginType: marginType,
    quoteCurrency: quoteCurrency,
    lastAppliedFundingTimestamp: lastAppliedFundingTimestamp,
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
  const balance = await contract.getSubAccountSpotBalance(BigInt(expectations.sub_account_id), expectations.currency)
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
  const balance = await contract.getAccountSpotBalance(expectations.account_id, expectations.currency)
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

async function expectExchangeCurrencyBalance(contract: Contract, expectations: ExExchangeCurrencyBalance) {
  const balance = await contract.getExchangeCurrencyBalance(expectations.currency)
  // expectations.balance is the sum of all spot balances of that currency, calculated in risk engine test
  // we cannot mint more fund than the total spot balance, which is the amount we hold
  expect(big(expectations.balance)).to.lessThanOrEqual(big(balance))
}

// this refers to the subaccount's spot balance in API
async function expectSubAccountSpotReal(contract: Contract, expectations: ExSubAccountSpotReal) {
  expect(expectations.currency).to.equal("USDT")
  const value = await contract.getSubAccountValue(BigInt(expectations.sub_account_id))
  expect(big(expectations.balance)).to.equal(big(value))
}

function getBalanceDecimalFromEnum(currency: number) {
  if (
    currency == CurrencyToEnum.BTC ||
    currency == CurrencyToEnum.ETH ||
    currency == CurrencyToEnum.SOL ||
    currency == CurrencyToEnum.BNB ||
    currency == CurrencyToEnum.AAVE
  ) {
    return 9
  } else if (
    currency == CurrencyToEnum.USD ||
    currency == CurrencyToEnum.USDC ||
    currency == CurrencyToEnum.USDT ||
    currency == CurrencyToEnum.ARB ||
    currency == CurrencyToEnum.ZK ||
    currency == CurrencyToEnum.POL ||
    currency == CurrencyToEnum.OP ||
    currency == CurrencyToEnum.ATOM ||
    currency == CurrencyToEnum.TON ||
    currency == CurrencyToEnum.XRP ||
    currency == CurrencyToEnum.XLM ||
    currency == CurrencyToEnum.WLD ||
    currency == CurrencyToEnum.WIF ||
    currency == CurrencyToEnum.VIRTUAL ||
    currency == CurrencyToEnum.TRUMP ||
    currency == CurrencyToEnum.SUI ||
    currency == CurrencyToEnum.KSHIB ||
    currency == CurrencyToEnum.POPCAT ||
    currency == CurrencyToEnum.PENGU ||
    currency == CurrencyToEnum.LINK ||
    currency == CurrencyToEnum.KBONK ||
    currency == CurrencyToEnum.JUP ||
    currency == CurrencyToEnum.FARTCOIN ||
    currency == CurrencyToEnum.ENA ||
    currency == CurrencyToEnum.DOGE ||
    currency == CurrencyToEnum.AIXBT ||
    currency == CurrencyToEnum.AI16Z ||
    currency == CurrencyToEnum.ADA ||
    currency == CurrencyToEnum.BERA ||
    currency == CurrencyToEnum.VINE ||
    currency == CurrencyToEnum.PENDLE ||
    currency == CurrencyToEnum.UXLINK ||
    currency == CurrencyToEnum.KAITO ||
    currency == CurrencyToEnum.IP
  ) {
    return 6
  } else if (currency == CurrencyToEnum.KPEPE) {
    return 3
  } else {
    throw new Error("Unsupported currency")
  }
}

async function expectSubAccountPositionOptional(contract: Contract, expectations: ExSubAccountPositionOptional) {
  let assetID = big(toAssetID(expectations.position.instrument))
  let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
  const [found, actualBalance] = await contract.getSubAccountPosition(
    BigInt(expectations.position.sub_account_id),
    assetIDHex
  )

  if (found) {
    const expectedPosSize =
      Number(expectations.position.size) * 10 ** getBalanceDecimalFromEnum(expectations.position.instrument.underlying)
    expect(Number(actualBalance)).to.equal(expectedPosSize)
  } else {
    // Accept both "0" and "0.0" as zero, and compare as numbers
    expect(Number(expectations.position.size)).to.equal(0)
  }
}

async function expectInsuranceFundLoss(contract: Contract, expectations: ExInsuranceFundLoss) {
  const loss = await contract.getInsuranceFundLoss(expectations.currency)
  expect(big(expectations.amount)).to.equal(big(loss))
}

async function expectTotalClientEquity(contract: Contract, expectations: ExTotalClientEquity) {
  const equity = await contract.getTotalClientEquity(expectations.currency)
  expect(big(expectations.amount)).to.equal(big(equity))
}

async function expectSubAccountSummaryOptional(contract: Contract, expectations: ExSubAccountSummaryOptional) {
  if (expectations.summary == null) {
    return
  }
  let sub = await getSubAccountResult(contract, expectations.summary.sub_account_id)

  if (expectations.summary.margin_type != null && expectations.summary.margin_type != "UNSPECIFIED") {
    expect(sub.marginType).to.equal(MarginTypeToEnum[expectations.summary.margin_type])
  }

  if (expectations.summary.settle_currency != null && expectations.summary.settle_currency != "UNSPECIFIED") {
    expect(sub.quoteCurrency).to.equal(CurrencyToEnum[expectations.summary.settle_currency])
  }

  if (expectations.summary.settle_index_price != null && expectations.summary.settle_index_price != "") {
    const quoteCurrency = CurrencyToEnum[expectations.summary.settle_currency ?? "UNSPECIFIED"]
    const underlyingCurrency = CurrencyToEnum[expectations.summary.settle_currency ?? "UNSPECIFIED"]
    let assetID = big(toAssetID({ kind: "SPOT", underlying: underlyingCurrency, quote: quoteCurrency }))
    let assetIDHex = ethers.utils.hexZeroPad(assetID.toHexString(), 32)
    const [price, found] = await contract.getMarkPrice(assetIDHex)
    expect(found).to.be.true
    expect(Number(expectations.summary.settle_index_price) * 10 ** 9).to.equal(Number(price))
  }

  if (expectations.summary.maintenance_margin != null && expectations.summary.maintenance_margin != "") {
    const maintenanceMargin = await contract.getSubAccountMaintenanceMargin(BigInt(expectations.summary.sub_account_id))
    expect(
      Number(expectations.summary.maintenance_margin) * 10 ** getBalanceDecimalFromEnum(sub.quoteCurrency)
    ).to.equal(Number(maintenanceMargin))
  }
}

async function expectNumSubAccountPositions(contract: Contract, expectations: ExNumSubAccountPositions) {
  const numPositions = await contract.getSubAccountPositionCount(BigInt(expectations.sub_account_id))
  expect(numPositions).to.equal(expectations.num_positions)
}

// Add implementations for vault-related expectations
async function expectVaultParams(contract: Contract, expectations: ExVaultParams) {
  // First check if the sub account exists and is a vault
  const isVault = await contract.isVault(BigInt(expectations.vault_id))
  expect(isVault).to.be.true

  // Get vault fees and check them against expectations
  const [managementFee, performanceFee, marketingFee] = await contract.getVaultFees(BigInt(expectations.vault_id))
  if (expectations.params_specs.management_fee_centi_beeps != "") {
    expect(managementFee / 10000).to.equal(Number(expectations.params_specs.management_fee_centi_beeps))
  }
  if (expectations.params_specs.performance_fee_centi_beeps != "") {
    expect(performanceFee / 10000).to.equal(Number(expectations.params_specs.performance_fee_centi_beeps))
  }
  if (expectations.params_specs.marketing_fee_centi_beeps != "") {
    expect(marketingFee / 10000).to.equal(Number(expectations.params_specs.marketing_fee_centi_beeps))
  }
}

async function expectVaultStatus(contract: Contract, expectations: ExVaultStatus) {
  // Verify the vault exists
  const isVault = await contract.isVault(BigInt(expectations.vault_id))
  expect(isVault).to.be.true

  // Get vault status and check it
  const status = await contract.getVaultStatus(BigInt(expectations.vault_id))

  // Convert status string to enum value using the VaultStatusToEnum mapping
  expect(status).to.equal(VaultStatusToEnum[expectations.status])
}

async function expectVaultTotalLpTokenSupply(contract: Contract, expectations: ExVaultTotalLpTokenSupply) {
  // Verify the vault exists
  const isVault = await contract.isVault(BigInt(expectations.vault_id))
  expect(isVault).to.be.true

  // Get total LP token supply and check it
  const totalSupply = await contract.getVaultTotalLpTokenSupply(BigInt(expectations.vault_id))
  expect(big(totalSupply)).to.equal(big(expectations.total_lp_token_supply))
}

async function expectVaultLpInfo(contract: Contract, expectations: ExVaultLpInfo) {
  // Verify the vault exists
  const isVault = await contract.isVault(BigInt(expectations.vault_id))
  expect(isVault).to.be.true

  // Get LP info and check it
  const [lpTokenBalance, usdNotionalInvested] = await contract.getVaultLpInfo(
    BigInt(expectations.vault_id),
    expectations.lp_account_id
  )

  expect(big(lpTokenBalance)).to.equal(big(expectations.lp_token_balance))
  expect(big(usdNotionalInvested)).to.equal(big(expectations.usd_notional_invested))
}

async function expectSubAccountUnderDeriskMargin(contract: Contract, expectations: ExSubAccountUnderDeriskMargin) {
  const underDeriskMargin = await contract.isUnderDeriskMargin(
    BigInt(expectations.sub_account_id),
    expectations.under_derisk_margin
  )
  expect(underDeriskMargin).to.equal(true)
}

async function expectCurrencyConfig(contract: Contract, expectations: ExCurrencyConfig) {
  const decimals = await contract.getCurrencyDecimals(expectations.id)
  expect(decimals).to.equal(expectations.balance_decimals)
}

async function expectCurrencyCount(contract: Contract, expectations: ExCurrencyCount) {
  // This is only implemented in risk, and not in contract (intentional)
}

function big(s: any): BigNumber {
  return BigNumber.from(s)
}
