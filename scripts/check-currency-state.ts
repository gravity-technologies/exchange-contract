import { task } from "hardhat/config"
import { Contract } from "ethers"
import * as fs from "fs"
import * as path from "path"
import * as yaml from "js-yaml"
import { createProviders } from "./utils"

interface CurrencyEntry {
  id: number
  balance_decimals: number
  name: string
}

task("check-currency-state", "Verify that all currencies in test/currencies.yaml are configured in the exchange contract")
  .addOptionalParam("exchangeAddr", "Exchange contract address (defaults to network config)")
  .setAction(async (taskArgs, hre) => {
    const exchangeAddr =
      taskArgs.exchangeAddr || (hre.config as any).contractAddresses?.[hre.network.name]?.exchange
    if (!exchangeAddr) {
      throw new Error(`No exchange address found for network "${hre.network.name}". Pass --exchange-addr or add it to contractAddresses in hardhat.config.ts`)
    }

    const { l2Provider } = createProviders(hre.config.networks, hre.network)

    const getterAbi = (await hre.artifacts.readArtifact("IGetter")).abi
    const exchange = new Contract(exchangeAddr, getterAbi, l2Provider)

    const currenciesPath = path.resolve(__dirname, "../test/currencies.yaml")
    const currencies = yaml.load(fs.readFileSync(currenciesPath, "utf8")) as CurrencyEntry[]

    console.log(`\nChecking ${currencies.length} currencies on ${hre.network.name} (${exchangeAddr})\n`)

    let passed = 0
    let failed = 0
    const failures: string[] = []

    for (const currency of currencies) {
      let actual: number
      try {
        actual = await exchange.getCurrencyDecimals(currency.id)
      } catch (err: any) {
        const msg = `  FAIL  ${currency.name.padEnd(12)} (id=${currency.id}): call reverted — ${err.message ?? err}`
        console.log(msg)
        failures.push(msg)
        failed++
        continue
      }

      if (actual === currency.balance_decimals) {
        console.log(`  OK    ${currency.name.padEnd(12)} (id=${currency.id}): decimals=${actual}`)
        passed++
      } else {
        const msg = `  FAIL  ${currency.name.padEnd(12)} (id=${currency.id}): expected=${currency.balance_decimals} actual=${actual}`
        console.log(msg)
        failures.push(msg)
        failed++
      }
    }

    console.log(`\n${passed} passed, ${failed} failed out of ${currencies.length} currencies`)

    if (failed > 0) {
      console.log("\nFailures:")
      for (const f of failures) console.log(f)
      throw new Error(`${failed} currency/currencies not configured correctly`)
    }
  })
