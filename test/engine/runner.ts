import { Contract, ethers } from "ethers"
import { Wallet } from "zksync-ethers"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { expectToThrowAsync } from "../util"
import { validateExpectations } from "./expect"
import { TestCase, TestStep } from "./types"
import { isDeposit, mockFinalizeDeposit } from "./deposit"
import { network } from "hardhat"

const GAS_LIMIT = 2100000000

export async function runTestCase(
  test: TestCase,
  exchangeContract: Contract,
  multicallContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: L2SharedBridge
) {
  for (const step of test.steps ?? []) {
    await executeTestStep(test.name, step, exchangeContract, multicallContract, w1, l2SharedBridgeAsL1Bridge)
  }
}

async function executeTestStep(
  testName: string,
  step: TestStep,
  exchangeContract: Contract,
  multicallContract: Contract,
  w1: Wallet,
  l2SharedBridgeAsL1Bridge: L2SharedBridge
) {
  if (step.tx_data === "") {
    await validateExpectations(exchangeContract, step.expectations)
    return
  }

  const tx: ethers.providers.TransactionRequest = {
    to: exchangeContract.address,
    gasLimit: GAS_LIMIT,
    data: step.tx_data,
  }

  const assertionTx = {
    to: exchangeContract.address,
    gasLimit: GAS_LIMIT,
    data: step.assertion_data,
  }

  if (isDeposit(step)) {
    await mockFinalizeDeposit(l2SharedBridgeAsL1Bridge, step.tx!.deposit!)
  }

  if (step.assertion_data !== "") {
    try {
      let snapshotId = await network.provider.send("evm_snapshot")
      const normalGasEstimate = await w1.sendTransaction(tx).then(r => r.wait()).then(r => r.gasUsed)
      await network.provider.send("evm_revert", [snapshotId])
      snapshotId = await network.provider.send("evm_snapshot")
      const multicallWOAssertion = [
        {
          target: exchangeContract.address,
          allowFailure: false,
          callData: exchangeContract.interface.encodeFunctionData("assertLastTxID", [Number(step.tx_id) - 1]),
        },
        {
          target: exchangeContract.address,
          allowFailure: false,
          callData: step.tx_data,
        }
      ]
      const multicallWOAssertionGasEstimate = await w1.sendTransaction({
        to: multicallContract.address,
        data: multicallContract.interface.encodeFunctionData("aggregate3", [multicallWOAssertion]),
        gasLimit: GAS_LIMIT,
      }).then(r => r.wait()).then(r => r.gasUsed)
      await network.provider.send("evm_revert", [snapshotId])
      snapshotId = await network.provider.send("evm_snapshot")
      const multicallWithAssertion = [
        ...multicallWOAssertion,
        {
          target: exchangeContract.address,
          allowFailure: false,
          callData: step.assertion_data,
        },
      ]
      const multicallWithAssertionGasEstimate = await w1.sendTransaction({
        to: multicallContract.address,
        data: multicallContract.interface.encodeFunctionData("aggregate3", [multicallWithAssertion]),
        gasLimit: GAS_LIMIT,
      }).then(r => r.wait()).then(r => r.gasUsed)
      await network.provider.send("evm_revert", [snapshotId])
      console.log(`GAS_BENCHMARK | ${step.tx!.type} | normal: ${normalGasEstimate} | multicallWOAssertion: ${multicallWOAssertionGasEstimate} | multicallWithAssertion: ${multicallWithAssertionGasEstimate} | ${testName} | txID: ${step.tx_id}`)
    } catch (e) {
      console.error("Error estimating gas for multicallWOAssertion. Check the input payload:", e)
      throw e
    }
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

    try {
      const resp = await w1.sendTransaction(assertionTx)
      await resp.wait()
    } catch (e) {
      console.error("Error sending assertion transaction. Check the input payload:", e)
      throw e
    }
  }
}
