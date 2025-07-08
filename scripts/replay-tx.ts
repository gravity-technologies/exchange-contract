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

task("replay", "Replay a specific transaction locally")
  .addParam("txHash", "Transaction hash to replay")
  .addOptionalParam("exchangeAddr", "Address of the exchange contract (overrides config)")
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

    const tx = await l2Provider.getTransaction(taskArgs.txHash)
    if (!tx) {
      throw new Error(`Transaction ${taskArgs.txHash} not found`)
    }

    const implAddressBytes = await l2Provider.getStorageAt(exchangeAddr, IMPLEMENTATION_SLOT, tx.blockNumber!)
    const implAddress = "0x" + implAddressBytes.slice(-40)

    console.log("Implementation address:", implAddress)

    // 3. Create temp directory and copy artifact
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'grvt-replay-'))
    console.log("Using temporary directory:", tempDir)

    // Write override JSON to file
    fs.writeFileSync(
      path.join(tempDir, `${implAddress}.json`),
      JSON.stringify(overrideJson, null, 2)
    )

    console.log("Building test node...")

    // 4. Run anvil-zksync in replay mode
    const anvilArgs = [
      "run",
      "--",
      "--override-bytecodes-dir=" + tempDir,
      "-vv",
      "replay_tx",
      "--fork-url",
      (hre.network.config as HttpNetworkConfig).url,
      taskArgs.txHash
    ]

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
