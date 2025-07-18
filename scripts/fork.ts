import { task } from "hardhat/config"
import fs from "fs"
import path from "path"
import os from "os"
import { spawn } from "child_process"
import { createProviders } from "./utils"
import { HttpNetworkConfig } from "hardhat/types"
import { hashBytecode } from "zksync-web3/build/src/utils"

// EIP-1967 storage slot for implementation address
const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

task("fork", "Fork network with implementation contract")
  .addOptionalParam("exchangeAddr", "Address of the exchange contract (overrides config)")
  .addOptionalParam("blockNumber", "Fork from specific block number")
  .addOptionalParam("txHash", "Fork from specific transaction hash")
  .setAction(async (taskArgs, hre) => {
    // Get exchange address from param or config
    const exchangeAddr = taskArgs.exchangeAddr ||
      (hre.config as any).contractAddresses?.[hre.network.name]?.exchange

    if (!exchangeAddr) {
      throw new Error(`No exchange address provided and none found in config for network ${hre.network.name}`)
    }

    // 1. Compile hardhat project
    await hre.run("compile")

    // Load GRVTExchange test artifact
    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")

    const overrideJson = {
      abi: exchangeArtifact.abi,
      bytecode: {
        object: exchangeArtifact.bytecode.replace('0x', ''),
      },
      methodIdentifiers: {},
      storageLayout: {
        storage: [],
        types: {}
      },
      userdoc: {},
      devdoc: {},
      hash: hashBytecode(exchangeArtifact.bytecode),
      factoryDependencies: {},
      id: 0
    }

    // 2. Query implementation address
    const { l2Provider } = createProviders(hre.config.networks, hre.network)
    const implAddressBytes = await l2Provider.getStorageAt(exchangeAddr, IMPLEMENTATION_SLOT)
    const implAddress = "0x" + implAddressBytes.slice(-40) // Convert to address format

    console.log("Implementation address:", implAddress)

    // 3. Create temp directory and copy artifact
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'grvt-fork-'))
    console.log("Using temporary directory:", tempDir)

    // Write override JSON to file named with implementation address
    fs.writeFileSync(
      path.join(tempDir, `${implAddress}.json`),
      JSON.stringify(overrideJson, null, 2)
    )

    // 4. Run anvil-zksync
    const anvilArgs = [
      "run",
      "--quiet",
      "--",
      "--override-bytecodes-dir=" + tempDir,
      "fork",
      "--fork-url",
      (hre.network.config as HttpNetworkConfig).url
    ]

    // Add optional fork arguments if provided
    if (taskArgs.blockNumber) {
      anvilArgs.push("--fork-block-number", taskArgs.blockNumber.toString())
    }
    if (taskArgs.transactionHash) {
      anvilArgs.push("--fork-transaction-hash", taskArgs.transactionHash)
    }

    const anvilProcess = spawn("cargo", anvilArgs, {
      cwd: path.join(__dirname, "../lib/anvil-zksync"),
      stdio: "inherit"
    })

    // 5. Clean up on process exit
    const cleanup = () => {
      if (fs.existsSync(tempDir)) {
        fs.rmSync(tempDir, { recursive: true })
      }
    }

    process.on('SIGINT', () => {
      anvilProcess.kill()
      cleanup()
      process.exit()
    })

    process.on('SIGTERM', () => {
      anvilProcess.kill()
      cleanup()
      process.exit()
    })

    // Wait for anvil to exit
    await new Promise((resolve) => {
      anvilProcess.on('close', () => {
        cleanup()
        resolve(null)
      })
    })
  })