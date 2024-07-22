import { Contract, ethers } from "ethers"
import { network } from "hardhat"
import { Wallet } from "zksync-ethers"
import { LOCAL_RICH_WALLETS, deployContract, getProvider, getWallet } from "../../deploy/utils"
import { expectToThrowAsync, getDeployerWallet } from "../util"
import { validateExpectations } from "./Getters"
import { DepositTxInfo, TestCase, TestStep, loadTestFilesFromDir, parseTestsFromFile } from "./TestEngineTypes"
import { L2SharedBridgeFactory } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { L2SharedBridge } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridge"
import { execSync } from 'child_process';
import path from 'path';

const gasLimit = 2100000000
const testDir = "/test/engine/testfixtures/"

let l2SharedBridgeAsL1Bridge: L2SharedBridge;

// We skip these tests in CI since the era test node cannot run these tests
describe.only("API - TestEngine", function () {
  let exchangeContract: Contract
  let runSnapshotId: string
  let testSnapshotId: string
  let w1 = getDeployerWallet()
  let testFiles = loadTestFilesFromDir(process.cwd() + testDir)


  before(async () => {
    runSnapshotId = await network.provider.send("evm_snapshot")

    const [
      deployerWallet,
      governorWallet,
      l1BridgeWallet,
    ] = LOCAL_RICH_WALLETS
      .slice(0, 3)
      .map(w => getWallet(w.privateKey));

    const deployOptions = { wallet: deployerWallet, silent: true, noVerify: true }

    exchangeContract = await deployContract("GRVTExchangeTest", [], deployOptions)
    await exchangeContract.initialize()

    // setup L2SharedBridge and BeaconProxy for L2StandardERC20 for deposit and withdrawal
    // DO NOT update the salt as it would change the deployed contract address, which is fixed across runs and 
    // hardcoded in risk RTF tests
    const result = execSync([
      'npx',
      'hardhat',
      'deploy-erc20-test-setup',
      '--deployer-private-key', deployerWallet.privateKey,
      '--governor-private-key', governorWallet.privateKey,
      '--l1-bridge-private-key', l1BridgeWallet.privateKey,
      '--salt', ethers.utils.keccak256(ethers.utils.toUtf8Bytes('test'))
    ].join(" "), { cwd: path.resolve('lib/era-contracts/l2-contracts'), stdio: 'pipe' });

    const l2SharedBridgeAddress = result.toString().trim();
    const l2SharedBridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, deployerWallet);

    // exchange address is required before ERC20 can be deployed
    await (await l2SharedBridge.setExchangeAddress(exchangeContract.address)).wait();

    l2SharedBridgeAsL1Bridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, l1BridgeWallet);
  })

  after(async () => {
    await network.provider.send("evm_revert", [runSnapshotId])
  })

  beforeEach(async () => {
    testSnapshotId = await network.provider.send("evm_snapshot")
  })

  afterEach(async () => {
    await network.provider.send("evm_revert", [testSnapshotId])
  })

  const filters: string[] = [
    "TestAccountMultisig.json",
    "TestAccountSigners.json",
    "TestConfigChain.json",
    "TestConfigChainDefault.json",
    "TestCreateAccount.json",
    "TestFundingRate.json",
    "TestInterestRate.json",
    "TestMarkPrice.json",
    "TestMatchFeeComputation.json",
    "TestMatchFundingAndSettlement.json",
    "TestMatchTradingComputation.json",
    "TestRecoverWallet.json",
    "TestSessionKey.json",
    "TestSettlementPrice.json",
    "TestSubAccount.json",
    "TestDeposit.json",
    "TestTransfer.json",
    "TestWithdrawal.json",
  ]
  const testNames: string[] = [
    // "[NoFee, NoMargin] One Leg One Maker (Simple Buy and Close)",
    // "[NoFee, NoMargin] One Leg One Maker (Simple Buy and Close)"
  ]
  testFiles
    .filter((t) => filters.includes(t))
    .forEach((file) => {
      describe(file, async function () {
        let tests = parseTestsFromFile(process.cwd() + testDir + file)
        tests = tests.filter((t) => testNames.length == 0 || testNames.includes(t.name))
        tests.slice().forEach((test) => {
          it(test.name + ` correctly runs`, async function () {
            await validateTest(test, exchangeContract, w1)
          })
        })
      })
    })
})

async function validateTest(test: TestCase, exchangeContract: Contract, w1: Wallet) {
  const steps = test.steps ?? []
  for (const step of steps) {
    if (step.tx_data == "") {
      await validateExpectations(exchangeContract, step.expectations)
      continue
    }

    var tx: ethers.providers.TransactionRequest = {
      to: exchangeContract.address,
      gasLimit: gasLimit,
      data: step.tx_data,
    }

    if (isDeposit(step)) {
      await mockFinalizeDeposit(step.tx!.deposit!)
    }

    w1 = w1.connect(getProvider())
    const resp = await w1.sendTransaction(tx)
    if (step.ret != "") {
      await expectToThrowAsync(resp.wait())
    } else {
      // console.log("Step", (step as any).tx.tx_id)
      await resp.wait()
      await validateExpectations(exchangeContract, step.expectations)
    }
  }

  return
}

const L2TokenInfo: {
  [key: string]: {
    l1Token: string;
    erc20Decimals: number;
    exchangeDecimals: number;
    name: string
  }
} = {
  "USDC": {
    l1Token: "0x1111000000000000000000000000000000001110",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "USD Coin",
  },
  "USDT": {
    l1Token: "0x1111000000000000000000000000000000001111",
    erc20Decimals: 6,
    exchangeDecimals: 6,
    name: "Tether USD",
  },
  "ETH": {
    l1Token: "0x1111000000000000000000000000000000001112",
    erc20Decimals: 18,
    exchangeDecimals: 9,
    name: "Ether",
  },
  "BTC": {
    l1Token: "0x1111000000000000000000000000000000001113",
    erc20Decimals: 8,
    exchangeDecimals: 9,
    name: "Wrapped Bitcoin",
  }
}

function isDeposit(step: TestStep) {
  return step.tx != undefined && step.tx.type == "DEPOSIT"
}
// finalizeDeposit will be called as a L1 -> L2 transaction on
// the L2 shared bridge as part of the deposit process.
// The BridgeMint event from L2StandardERC20 triggers a deposit
// transaction on Risk and the exchange contract, which calls the
// fundExchangeAccount method on the L2StandardERC20 to transfer the
// deposited amount to the exchange.
async function mockFinalizeDeposit(
  deposit: DepositTxInfo
) {
  const currency = deposit.token_currency;

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
      encodedTokenData(
        L2TokenInfo[currency].name,
        currency,
        L2TokenInfo[currency].erc20Decimals
      ),
    )
  } else {
    console.log(`🚨 Unknown currency - add the currency in your test: ${currency} 🚨 `)
  }
}

const L1_TO_L2_ALIAS_OFFSET = "0x1111000000000000000000000000000000001111";
const ADDRESS_MODULO = ethers.BigNumber.from(2).pow(160);

export function unapplyL1ToL2Alias(address: string): string {
  // We still add ADDRESS_MODULO to avoid negative numbers
  return ethers.utils.hexlify(
    ethers.BigNumber.from(address).sub(L1_TO_L2_ALIAS_OFFSET).add(ADDRESS_MODULO).mod(ADDRESS_MODULO)
  );
}

function encodedTokenData(name: string, symbol: string, decimals: number) {
  const abiCoder = ethers.utils.defaultAbiCoder;
  const encodedName = abiCoder.encode(["string"], [name]);
  const encodedSymbol = abiCoder.encode(["string"], [symbol]);
  const encodedDecimals = abiCoder.encode(["uint8"], [decimals]);

  return abiCoder.encode(["bytes", "bytes", "bytes"], [encodedName, encodedSymbol, encodedDecimals]);
}

/**
 * Scale a string representing a bigint from one decimal precision to another.
 * @param {string} valueStr - The original value as a string.
 * @param {number} currentDecimals - The current number of decimals.
 * @param {number} newDecimals - The desired number of decimals.
 * @returns {string} - The scaled value as a string.
 */
function scaleBigInt(valueStr: string, currentDecimals: number, newDecimals: number): string {
  const value = BigInt(valueStr);

  let scaledValue: bigint;

  if (currentDecimals < newDecimals) {
    // Scale up by multiplying by 10^(newDecimals - currentDecimals)
    scaledValue = value * BigInt(10 ** (newDecimals - currentDecimals));
  } else if (currentDecimals > newDecimals) {
    // Scale down by dividing by 10^(currentDecimals - newDecimals)
    scaledValue = value / BigInt(10 ** (currentDecimals - newDecimals));
  } else {
    // No scaling needed
    scaledValue = value;
  }

  return scaledValue.toString();
}
