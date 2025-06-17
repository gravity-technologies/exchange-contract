// A Test is a sequence of test cases
export type Test = TestCase[]

export interface TestCase {
  // Name of the test case
  name: string
  // A test case is a sequence of test steps
  steps: TestStep[]
}

// A test step is a transaction to be executed and the expected result
export interface TestStep {
  // The time at which the transaction is executed (if left blank, its value is the same as the previous test step)

  // The txID of the transaction to be executed
  tx_id: string

  // The function abi encoded transaction to be executed
  tx_data: string

  // The expected result of running the transaction
  error: string

  // List of expectations to be executed after the transaction is executed
  expectations: Expectation[]

  tx: TxInfo | undefined

  // The assertion data to be executed after the transaction is executed
  assertion_data: string
}

export interface TxInfo {
  type: string
  deposit: DepositTxInfo | undefined
}

export interface DepositTxInfo {
  to_account_id: string
  token_currency: string
  num_tokens: string
  currency: string
}

export interface ExNumAccounts {
  num_accounts: number
  account_ids: string[]
}

// Expects an account with the given address to be created, and have listed signers with the given permissions
export interface ExAccountSigners {
  address: string
  signers: { [address: string]: string }
}

// Expects an account with the given address to have the given multi-sig threshold
export interface ExAccountMultiSigThreshold {
  address: string
  multi_sig_threshold: number
}

// Expects a sub-account with signers with the given permissions
export interface ExSubAccountSigners {
  sub_account_id: string
  signers: { [address: string]: string }
}

// Expects a sub-account with the given margin type
export interface ExSubAccountMarginType {
  sub_account_id: string
  margin_type: string
}

export interface SessionValue {
  main_signing_key: string
  session_key: string
  authorization_expiry_delta: string
}

export interface ExSessionKeys {
  signers: { [address: string]: SessionValue }
}

export interface ExAccountWithdrawalAddresses {
  address: string
  withdrawal_addresses: string[]
}

export interface ExConfigSchedule {
  key: string
  sub_key: string
  value: string
  lock_end_delta: string
}

export interface ExConfigScheduleAbsent {
  key: string
  sub_key: string
}

export interface ExConfig1D {
  key: string
  value: string
}

export interface ExConfig2D {
  key: string
  sub_key: string
  value: string
}

export interface Asset {
  kind: string
  underlying: string
  quote: string
  strike_price?: string
  expiration?: string
}

export interface ExFundingIndex {
  asset_dto: Asset
  funding_rate: string
}

export interface ExFundingTimeDelta {
  funding_time_delta: string
}

export interface ExMarkPrice {
  asset_dto: Asset
  mark_price: string
}

export interface ExInterestRate {
  asset_dto: Asset
  interest_rate: string
}

// Trade
export interface ExSubAccountValue {
  sub_account_id: string
  value: string
}

export interface Position {
  asset: Asset
  balance: string
  last_applied_funding_index: string
}

export interface ExSubAccountPosition {
  sub_account_id: string
  asset: Asset
  position: Position
}

export interface ExSubAccountSpot {
  sub_account_id: string
  currency: string
  balance: string
}

export interface ExSettlementPrice {
  asset_dto: Asset
  settlement_price: string
}

export interface ExAccountRecoveryAddresses {
  address: string
  recovery_addresses: { [address: string]: string[] }
}

export interface ExNotAccountRecoveryAddresses {
  address: string
  not_recovery_addresses: { [address: string]: string[] }
}

export interface ExAccountSpot {
  account_id: string
  currency: string
  balance: string
}

export interface ExConfigNotSet {
  key: string
}

export interface ExConfig2DNotSet {
  key: string
}

export interface ExSimpleCrossMaintenanceMarginTiers {
  kuq: string
  tiers: MarginTier[]
}

export interface MarginTier {
  bracket_start: string
  rate: string
}

export interface ExSimpleCrossMaintenanceMarginTimelockEndTime {
  kuq: string
  timelock_end_time_delta: string
}

export interface ExSimpleCrossMaintenanceMarginTiersNoTimelock {
  kuq: string
}

export interface ExSubAccountMaintMargin {
  sub_account_id: string
  maint_margin: string
}

export interface ExOnboardedTransferAccount {
  account_id: string
  transfer_account: string
}

export interface ExExchangeCurrencyBalance {
  currency: string
  balance: string
}

export interface ExNumSubAccountPositions {
  sub_account_id: string
  num_positions: number
}

export interface ExSubAccountSpotReal {
  sub_account_id: string
  currency: string
  balance: string
}

export interface ExSubAccountPositionOptional {
  position: {
    event_time: string
    sub_account_id: string
    instrument: Asset
    size: string
    notional: string
    entry_price: string
    exit_price: string
    mark_price: string
    unrealized_pnl: string
    realized_pnl: string
    total_pnl: string
    roi: number
    quote_index_price: string
  }
}

export interface ExInsuranceFundLoss {
  amount: string
  currency: string
}

export interface ExTotalClientEquity {
  amount: string
  currency: string
}

export interface ExVaultParams {
  vault_id: string
  params_specs: {
    management_fee_centi_beeps: string
    performance_fee_centi_beeps: string
    marketing_fee_centi_beeps: string
  }
}

export interface ExVaultStatus {
  vault_id: string
  status: string  // "ACTIVE", "DELISTED", or "CLOSED"
}

export interface ExVaultTotalLpTokenSupply {
  vault_id: string
  total_lp_token_supply: string
}

export interface ExVaultLpInfo {
  vault_id: string
  lp_account_id: string
  lp_token_balance: string
  usd_notional_invested: string
}

export interface ExSubAccountSummaryOptional {
  summary: {
    event_time: string
    sub_account_id: string
    margin_type: string
    settle_currency: string
    unrealized_pnl: string
    total_equity: string
    initial_margin: string
    maintenance_margin: string
    available_balance: string
    spot_balances: null
    positions: null
    settle_index_price: string
  }
  open_orders: []
  pre_trade_initial_margin: string
}

export interface ExSubAccountUnderDeriskMargin {
  sub_account_id: string
  under_derisk_margin: boolean
}

export interface ExCurrencyConfig {
  id: number
  balance_decimals: number
}

export interface ExCurrencyCount {
  count: number
}

export interface Expectation {
  name: string
  expect:
  | ExNumAccounts
  | ExAccountSigners
  | ExAccountMultiSigThreshold
  | ExAccountWithdrawalAddresses
  | ExSessionKeys
  | ExConfig1D
  | ExConfig2D
  | ExConfigSchedule
  | ExConfigScheduleAbsent
  | ExSubAccountSigners
  | ExSubAccountMarginType
  | ExFundingIndex
  | ExMarkPrice
  | ExInterestRate
  | ExFundingTimeDelta
  | ExSubAccountValue
  | ExSubAccountPosition
  | ExSubAccountSpot
  | ExSettlementPrice
  | ExAccountRecoveryAddresses
  | ExNotAccountRecoveryAddresses
  | ExAccountSpot
  | ExSimpleCrossMaintenanceMarginTiers
  | ExSimpleCrossMaintenanceMarginTimelockEndTime
  | ExSimpleCrossMaintenanceMarginTiersNoTimelock
  | ExSubAccountMaintMargin
  | ExOnboardedTransferAccount
  | ExSubAccountSummaryOptional
  | ExSubAccountSpotReal
  | ExSubAccountPositionOptional
  | ExNumSubAccountPositions
  | ExInsuranceFundLoss
  | ExTotalClientEquity
  | ExVaultParams
  | ExVaultStatus
  | ExVaultTotalLpTokenSupply
  | ExVaultLpInfo
  | ExSubAccountUnderDeriskMargin
  | ExCurrencyConfig
  | ExCurrencyCount
}
