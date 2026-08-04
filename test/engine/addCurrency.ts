import { TestStep } from "./types"

export function isAddCurrency(step: TestStep): boolean {
  return step.tx?.type === "ADD_CURRENCY" && step.tx.add_currency !== undefined
}

interface AddedCurrencyTokenInfo {
  l1Token: string
  erc20Decimals: number
  exchangeDecimals: number
  name: string
}

const addedCurrencyTokenInfo: { [key: number]: AddedCurrencyTokenInfo } = {}

// Runtime-added currencies use synthetic L1 token addresses. The BDD fixture
// writes erc20Addresses to the L2 token address that L2SharedBridge derives
// from this same synthetic L1 token.
export async function registerAddedCurrency(step: TestStep) {
  const ac = step.tx!.add_currency!
  const l1Token = syntheticL1Token(ac.id)

  addedCurrencyTokenInfo[ac.id] = {
    l1Token,
    erc20Decimals: ac.balance_decimals,
    exchangeDecimals: ac.balance_decimals,
    name: ac.name,
  }
}

export function getAddedCurrencyTokenInfo(currencyId: number): AddedCurrencyTokenInfo | undefined {
  return addedCurrencyTokenInfo[currencyId]
}

function syntheticL1Token(currencyId: number): string {
  const suffix = currencyId.toString(16).padStart(4, "0")
  return `0x111100000000000000000000000000000000${suffix}`
}
