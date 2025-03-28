import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { expectToThrowAsync } from "../util"
import { validateExpectations } from "./expect"
import { TestCase, TestStep } from "./types"
import { isDeposit, mockFinalizeDeposit } from "./deposit"

const GAS_LIMIT = 2100000000

export async function runTestCase(
  test: TestCase,
  exchangeContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: Contract
) {
  for (const step of test.steps ?? []) {
    await executeTestStep(step, exchangeContract, w1, l2SharedBridgeAsL1Bridge)
  }
}

async function executeTestStep(
  step: TestStep,
  exchangeContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: Contract
) {
  if (step.tx_data === "") {
    await validateExpectations(exchangeContract, step.expectations)
    return
  }

  const tx: ethers.TransactionRequest = {
    to: exchangeContract.target,
    gasLimit: GAS_LIMIT,
    data: step.tx_data,
  }

  if (isDeposit(step)) {
    await mockFinalizeDeposit(l2SharedBridgeAsL1Bridge, step.tx!.deposit!, exchangeContract)
  }

  try {
    const resp = await w1.sendTransaction(tx)
    if (step.error !== "") {
      await expectToThrowAsync(resp.wait())
    } else {
      await resp.wait()
      await validateExpectations(exchangeContract, step.expectations)
    }
  } catch (e) {
    console.error("Error sending transaction. Check the input payload:", e)
    throw e
  }

  if (step.assertion_data !== "") {
    const assertionTx = {
      to: exchangeContract.target,
      gasLimit: GAS_LIMIT,
      data: step.assertion_data,
    }
    try {
      const resp = await w1.sendTransaction(assertionTx)
      await resp.wait()
    } catch (e) {
      console.error("Error sending assertion transaction. Check the input payload:", e)
      throw e
    }
  }
}
