import * as Fs from "fs"

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
  ret: string

  // List of expectations to be executed after the transaction is executed
  expectations: Expectation[]
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
  authorization_expiry: string
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
  lock_end: string
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

export interface ExFundingTime {
  funding_time: string
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
    | ExFundingTime
    | ExMarkPrice
    | ExInterestRate
    | ExSubAccountValue
    | ExSubAccountPosition
    | ExSubAccountSpot
    | ExSettlementPrice
}

export function parseTestsFromFile(filePath: string): TestCase[] {
  try {
    // Read the JSON file
    const data = Fs.readFileSync(filePath, "utf8")

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

export function loadTestFilesFromDir(dir: string): string[] {
  return Fs.readdirSync(dir).map((file) => `${file}`)
}
