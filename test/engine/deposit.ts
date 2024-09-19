import { ethers } from "ethers"
import { L2TokenInfo } from "../../deploy/testutil"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { DepositTxInfo, TestStep } from "./types"
import { scaleBigInt } from "./util"

export function isDeposit(step: TestStep) {
  return step.tx != undefined && step.tx.type == "DEPOSIT"
}
// finalizeDeposit will be called as a L1 -> L2 transaction on
// the L2 shared bridge as part of the deposit process.
// The BridgeMint event from L2StandardERC20 triggers a deposit
// transaction on Risk and the exchange contract, which calls the
// fundExchangeAccount method on the L2StandardERC20 to transfer the
// deposited amount to the exchange.
export async function mockFinalizeDeposit(l2SharedBridgeAsL1Bridge: L2SharedBridge, deposit: DepositTxInfo) {
  const currency = deposit.token_currency

  const rawAmount = scaleBigInt(
    deposit.num_tokens,
    L2TokenInfo[currency].exchangeDecimals,
    L2TokenInfo[currency].erc20Decimals
  )

  if (currency in L2TokenInfo) {
    await l2SharedBridgeAsL1Bridge.finalizeDeposit(
      // Depositor and l2Receiver can be any here
      deposit.to_account_id,
      deposit.to_account_id,
      L2TokenInfo[currency].l1Token,
      rawAmount,
      encodedTokenData(L2TokenInfo[currency].name, currency, L2TokenInfo[currency].erc20Decimals)
    )
  } else {
    console.log(`🚨 Unknown currency - add the currency in your test: ${currency} 🚨 `)
  }
}

function encodedTokenData(name: string, symbol: string, decimals: number) {
  const abiCoder = ethers.utils.defaultAbiCoder
  const encodedName = abiCoder.encode(["string"], [name])
  const encodedSymbol = abiCoder.encode(["string"], [symbol])
  const encodedDecimals = abiCoder.encode(["uint8"], [decimals])
  return abiCoder.encode(["bytes", "bytes", "bytes"], [encodedName, encodedSymbol, encodedDecimals])
}

// const L1_TO_L2_ALIAS_OFFSET = "0x1111000000000000000000000000000000001111"
// const ADDRESS_MODULO = ethers.BigNumber.from(2).pow(160)
// export function unapplyL1ToL2Alias(address: string): string {
//   // We still add ADDRESS_MODULO to avoid negative numbers
//   return ethers.utils.hexlify(
//     ethers.BigNumber.from(address).sub(L1_TO_L2_ALIAS_OFFSET).add(ADDRESS_MODULO).mod(ADDRESS_MODULO)
//   )
// }
