import { task } from "hardhat/config"
import fs from "fs"
import path from "path"
import os from "os"
import { spawn } from "child_process"
import { createProviders, getLocalFacetInfo, getOnChainFacetInfo } from "./utils"
import { HttpNetworkConfig } from "hardhat/types"
import { hashBytecode } from "zksync-web3/build/src/utils"
import { HardhatRuntimeEnvironment } from "hardhat/types"

// EIP-1967 storage slot for implementation address
const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

/**
 * Create override JSON for anvil-zksync
 */
async function createOverrideJson(hre: HardhatRuntimeEnvironment, artifactName: string) {
  const artifact = await hre.artifacts.readArtifact(artifactName)

  return {
    abi: artifact.abi,
    bytecode: {
      object: artifact.bytecode.replace('0x', ''),
    },
    methodIdentifiers: {},
    storageLayout: {
      storage: [],
      types: {}
    },
    userdoc: {},
    devdoc: {},
    hash: hashBytecode(artifact.bytecode),
    factoryDependencies: {},
    id: 0
  }
}

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

    // 2. Query transaction and get facet info
    const { l2Provider } = createProviders(hre.config.networks, hre.network)

    const tx = await l2Provider.getTransaction(taskArgs.txHash)
    if (!tx) {
      throw new Error(`Transaction ${taskArgs.txHash} not found`)
    }

    const onChainFacetInfo = await getOnChainFacetInfo(hre, exchangeAddr, l2Provider)
    const localFacetInfo = await getLocalFacetInfo(hre)

    console.log(`Found ${onChainFacetInfo.length} on-chain facets and ${localFacetInfo.length} local facets`)

    // 3. Create temp directory and generate override JSONs for matching facets
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'grvt-replay-'))
    console.log("Using temporary directory:", tempDir)

    // For each on-chain facet, find a local facet with exactly the same selectors
    let overrideCount = 0
    for (const onChainFacet of onChainFacetInfo) {
      const matchingLocalFacet = localFacetInfo.find(localFacet => {
        // Check if selectors match exactly
        if (onChainFacet.selectors.length !== localFacet.selectors.length) {
          return false
        }

        const onChainSelectorsSet = new Set(onChainFacet.selectors)
        const localSelectorsSet = new Set(localFacet.selectors)

        return onChainFacet.selectors.every((selector: string) => localSelectorsSet.has(selector)) &&
          localFacet.selectors.every((selector: string) => onChainSelectorsSet.has(selector))
      })

      if (matchingLocalFacet) {
        console.log(`Creating override for facet ${matchingLocalFacet.facet} at address ${onChainFacet.address}`)

        const overrideJson = await createOverrideJson(hre, matchingLocalFacet.facet)
        fs.writeFileSync(
          path.join(tempDir, `${onChainFacet.address}.json`),
          JSON.stringify(overrideJson, null, 2)
        )
        overrideCount++
      } else {
        console.log(`No matching local facet found for on-chain facet at ${onChainFacet.address}`)
      }
    }

    // Also create override for the main implementation (GRVTExchange)
    const implAddressBytes = await l2Provider.getStorageAt(exchangeAddr, IMPLEMENTATION_SLOT, tx.blockNumber!)
    const implAddress = "0x" + implAddressBytes.slice(-40)

    console.log("Implementation address:", implAddress)
    const mainOverrideJson = await createOverrideJson(hre, "GRVTExchange")
    fs.writeFileSync(
      path.join(tempDir, `${implAddress}.json`),
      JSON.stringify(mainOverrideJson, null, 2)
    )
    overrideCount++

    console.log(`Created ${overrideCount} override JSON files`)

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
