import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { expectToThrowAsync } from "../util"
import { validateExpectations } from "./expect"
import { TestCase, TestStep } from "./types"
import { isDeposit, mockFinalizeDeposit } from "./deposit"
import * as testInfo from "./test-info.json"

const GAS_LIMIT = 2100000000
const DEBUG = false

export async function runTestCase(
  test: TestCase,
  exchangeContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: L2SharedBridge
) {
  for (const step of test.steps ?? []) {
    if (DEBUG) {
      console.log(`Executing step ${step.tx_id} of ${step.tx?.type}`)
    }
    await executeTestStep(step, exchangeContract, w1, l2SharedBridgeAsL1Bridge)
  }
}

async function executeTestStep(
  step: TestStep,
  exchangeContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: L2SharedBridge
) {
  if (step.tx_data === "") {
    await validateExpectations(exchangeContract, step.expectations)
    return
  }

  // Check if this is a risk-only constraint that should be skipped
  if (step.error !== "" && testInfo.risk_only_constraints.includes(step.error)) {
    if (DEBUG) {
      console.log(`Skipping transaction for risk-only constraint: ${step.error}`)
    }
    await validateExpectations(exchangeContract, step.expectations)
    return
  }

  const tx: ethers.providers.TransactionRequest = {
    to: exchangeContract.address,
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
      to: exchangeContract.address,
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
