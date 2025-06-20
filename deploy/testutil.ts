export const L2TokenInfo: {
  [key: number]: {
    l1Token: string
    erc20Decimals: number
    exchangeDecimals: number
    name: string
  }
} = {
  2: {
    l1Token: "0x1111000000000000000000000000000000001110",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "USD Coin",
  },
  3: {
    l1Token: "0x1111000000000000000000000000000000001111",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "Tether USD",
  },
  4: {
    l1Token: "0x1111000000000000000000000000000000001112",
    erc20Decimals: 18,
    exchangeDecimals: 9,
    name: "Ether",
  },
  5: {
    l1Token: "0x1111000000000000000000000000000000001113",
    erc20Decimals: 8,
    exchangeDecimals: 9,
    name: "Wrapped Bitcoin",
  },
}
