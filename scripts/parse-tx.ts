import { task } from "hardhat/config"
import { createProviders } from "./utils"
import { Interface } from "ethers/lib/utils"
import { ExchangeFacetInfos } from "./diamond-info"

interface CallTrace {
  from: string
  to: string
  input?: string
  output?: string
  revertReason?: string
  calls?: CallTrace[]
}

interface RevertContext {
  call: CallTrace
  previousCall?: CallTrace
}

function findRevertInCalls(calls: CallTrace[] | undefined, multicallAddr: string, exchangeAddr: string, includeContext = false): RevertContext | null {
  if (!calls) return null

  for (const call of calls) {
    // For multicall contracts, we need to look at their internal calls
    if (call.calls?.length) {
      let lastExchangeCall: CallTrace | undefined

      for (const innerCall of call.calls) {
        if (innerCall.from?.toLowerCase() === multicallAddr.toLowerCase() && innerCall.to?.toLowerCase() === exchangeAddr.toLowerCase()) {
          if (innerCall.revertReason) {
            return {
              call: innerCall,
              previousCall: includeContext ? lastExchangeCall : undefined
            }
          }
          lastExchangeCall = innerCall
        }

        // Also check deeper calls
        const innerRevert = findRevertInCalls([innerCall], multicallAddr, exchangeAddr, includeContext)
        if (innerRevert) return innerRevert
      }
    }

    // Direct call to exchange
    if (call.from?.toLowerCase() === multicallAddr.toLowerCase() && call.to?.toLowerCase() === exchangeAddr.toLowerCase() && call.revertReason) {
      return { call }
    }
  }

  return null
}

function parseArguments(functionFragment: any, decodedData: any) {
  return Object.keys(decodedData)
    .filter(k => isNaN(Number(k))) // Filter out numeric indices
    .reduce((acc: any, key) => {
      const value = decodedData[key]
      const param = functionFragment.inputs.find((input: any) => input.name === key)

      if (param?.components) {
        // This is a struct or array of structs
        if (param.type.includes('[]')) {
          // Handle array of structs
          if (Array.isArray(value)) {
            acc[key] = value.map((item: any) => parseStruct(item, param.components))
          } else {
            // Handle comma-separated string case
            const values = value.toString().split(',')
            const structSize = param.components.length
            const structs = []

            for (let i = 0; i < values.length; i += structSize) {
              const struct = param.components.reduce((obj: any, comp: any, idx: number) => {
                obj[comp.name] = values[i + idx]
                return obj
              }, {})
              structs.push(struct)
            }
            acc[key] = structs
          }
        } else {
          // Single struct
          acc[key] = parseStruct(value, param.components)
        }
      } else {
        acc[key] = value?.toString ? value.toString() : value
      }
      return acc
    }, {})
}

function parseStruct(value: any, components: any[]): any {
  const result: any = {}

  components.forEach((component: any, index: number) => {
    const fieldValue = value[index] || value[component.name]

    if (component.components) {
      // Nested struct
      if (component.type.includes('[]')) {
        // Array of nested structs
        result[component.name] = Array.isArray(fieldValue)
          ? fieldValue.map((item: any) => parseStruct(item, component.components))
          : parseStruct(fieldValue, component.components)
      } else {
        // Single nested struct
        result[component.name] = parseStruct(fieldValue, component.components)
      }
    } else {
      result[component.name] = fieldValue?.toString ? fieldValue.toString() : fieldValue
    }
  })

  return result
}

function formatCallData(call: CallTrace, exchangeInterface: Interface, facetInterfaces: Map<string, Interface>): string {
  try {
    const selector = call.input?.slice(0, 10)

    // First try the main exchange interface
    try {
      const functionFragment = exchangeInterface.getFunction(selector || "0x")
      const decodedData = call.input ?
        exchangeInterface.decodeFunctionData(functionFragment, call.input) : null

      const args = decodedData ? parseArguments(functionFragment, decodedData) : null

      return `${functionFragment.name}(${args ? JSON.stringify(args, null, 2) : 'no args'})`
    } catch (e) {
      // If main interface fails, try facet interfaces
      for (const [facetName, facetInterface] of facetInterfaces) {
        try {
          const functionFragment = facetInterface.getFunction(selector || "0x")
          const decodedData = call.input ?
            facetInterface.decodeFunctionData(functionFragment, call.input) : null

          const args = decodedData ? parseArguments(functionFragment, decodedData) : null

          return `[${facetName}] ${functionFragment.name}(${args ? JSON.stringify(args, null, 2) : 'no args'})`
        } catch (facetError) {
          // Continue to next facet
          continue
        }
      }

      // If no facet interface works, return raw input
      return call.input || 'no input'
    }
  } catch (e) {
    return call.input || 'no input'
  }
}

function findAllExchangeCalls(calls: CallTrace[] | undefined, multicallAddr: string, exchangeAddr: string): CallTrace[] {
  if (!calls) return []

  const exchangeCalls: CallTrace[] = []

  for (const call of calls) {
    // For multicall contracts, look at their internal calls
    if (call.calls?.length) {
      for (const innerCall of call.calls) {
        let callFound = false;
        if (innerCall.from?.toLowerCase() === multicallAddr.toLowerCase() && innerCall.to?.toLowerCase() === exchangeAddr.toLowerCase()) {
          callFound = true;
          exchangeCalls.push(innerCall)
        }

        // Also check deeper calls
        if (!callFound) {
          exchangeCalls.push(...findAllExchangeCalls([innerCall], multicallAddr, exchangeAddr))
        }
      }
    }

    // Direct call to exchange
    if (call.from?.toLowerCase() === multicallAddr.toLowerCase() && call.to?.toLowerCase() === exchangeAddr.toLowerCase()) {
      exchangeCalls.push(call)
    }
  }

  return exchangeCalls
}

task("find-contract-error", "Find contract error in a specific transaction")
  .addParam("txHash", "Transaction hash to analyze")
  .addOptionalParam("exchangeAddr", "Address of the exchange contract (overrides config)")
  .addFlag("showCalldata", "Show raw calldata in output")
  .setAction(async (taskArgs, hre) => {
    // Get exchange address from param or config
    const exchangeAddr = taskArgs.exchangeAddr ||
      (hre.config as any).contractAddresses?.[hre.network.name]?.exchange

    const multicallAddr = (hre.config as any).contractAddresses?.[hre.network.name]?.multicall3

    if (!exchangeAddr) {
      throw new Error(`No exchange address provided and none found in config for network ${hre.network.name}`)
    }

    const { l2Provider } = createProviders(hre.config.networks, hre.network)

    // Verify transaction exists
    const tx = await l2Provider.getTransaction(taskArgs.txHash)
    if (!tx) {
      throw new Error(`Transaction ${taskArgs.txHash} not found`)
    }

    // Load GRVTExchange artifact and create interface
    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
    const exchangeInterface = new Interface(exchangeArtifact.abi)

    // Load all facet interfaces
    const facetInterfaces = new Map<string, Interface>()
    for (const facetInfo of ExchangeFacetInfos) {
      try {
        const facetArtifact = await hre.artifacts.readArtifact(facetInfo.interface)
        facetInterfaces.set(facetInfo.facet, new Interface(facetArtifact.abi))
      } catch (e) {
        console.warn(`Warning: Could not load interface for ${facetInfo.interface}`)
      }
    }

    const response = await l2Provider.send("debug_traceTransaction", [
      taskArgs.txHash,
      { tracer: "callTracer" }
    ])

    // Find revert in call tree, include context for assertion errors
    const revertContext = findRevertInCalls(
      [response],
      multicallAddr,
      exchangeAddr,
      true // Include context for all calls to help with debugging
    )

    if (revertContext) {
      const { call: revertCall, previousCall } = revertContext

      console.log("\nFound exchange contract error:")
      console.log("─".repeat(50))

      try {
        const selector = revertCall.input?.slice(0, 10)

        // Try to find the function in main interface or facet interfaces
        let functionFragment: any = null
        let interfaceName = "GRVTExchange"

        try {
          functionFragment = exchangeInterface.getFunction(selector || "0x")
        } catch (e) {
          // Try facet interfaces
          for (const [facetName, facetInterface] of facetInterfaces) {
            try {
              functionFragment = facetInterface.getFunction(selector || "0x")
              interfaceName = facetName
              break
            } catch (facetError) {
              continue
            }
          }
        }

        if (functionFragment) {
          const isAssertionError = functionFragment.name.startsWith('assert')

          if (previousCall && isAssertionError) {
            console.log("Previous successful call:")
            console.log(formatCallData(previousCall, exchangeInterface, facetInterfaces))
            console.log("─".repeat(50))
            console.log("\nFailed assertion:")
          }

          console.log(formatCallData(revertCall, exchangeInterface, facetInterfaces))
          console.log("─".repeat(50))
          console.log("\nRevert reason:", revertCall.revertReason)

          if (taskArgs.showCalldata) {
            console.log("─".repeat(50))
            console.log("\nRaw calldata:")
            console.log(revertCall.input)
          }
        } else {
          console.log("Could not decode call data")
          console.log("─".repeat(50))
          console.log("Revert reason:", revertCall.revertReason)
        }
      } catch (e) {
        console.log("Could not decode call data")
        console.log("─".repeat(50))
        console.log("Revert reason:", revertCall.revertReason)
      }

      console.log("─".repeat(50))
    } else {
      console.log("No contract errors found in transaction")
    }
  })

task("view-contract-calls", "View all calls to exchange contract in a transaction")
  .addParam("txHash", "Transaction hash to analyze")
  .addOptionalParam("exchangeAddr", "Address of the exchange contract (overrides config)")
  .addFlag("showCalldata", "Show raw calldata in output")
  .setAction(async (taskArgs, hre) => {
    // Get exchange address from param or config
    const exchangeAddr = taskArgs.exchangeAddr ||
      (hre.config as any).contractAddresses?.[hre.network.name]?.exchange

    const multicallAddr = (hre.config as any).contractAddresses?.[hre.network.name]?.multicall3

    if (!exchangeAddr) {
      throw new Error(`No exchange address provided and none found in config for network ${hre.network.name}`)
    }

    const { l2Provider } = createProviders(hre.config.networks, hre.network)

    // Verify transaction exists
    const tx = await l2Provider.getTransaction(taskArgs.txHash)
    if (!tx) {
      throw new Error(`Transaction ${taskArgs.txHash} not found`)
    }

    // Load GRVTExchange artifact and create interface
    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
    const exchangeInterface = new Interface(exchangeArtifact.abi)

    // Load all facet interfaces
    const facetInterfaces = new Map<string, Interface>()
    for (const facetInfo of ExchangeFacetInfos) {
      try {
        const facetArtifact = await hre.artifacts.readArtifact(facetInfo.interface)
        facetInterfaces.set(facetInfo.facet, new Interface(facetArtifact.abi))
      } catch (e) {
        console.warn(`Warning: Could not load interface for ${facetInfo.interface}`)
      }
    }

    const response = await l2Provider.send("debug_traceTransaction", [
      taskArgs.txHash,
      { tracer: "callTracer" }
    ])

    // Find all exchange calls in the transaction
    const exchangeCalls = findAllExchangeCalls([response], multicallAddr, exchangeAddr)

    if (exchangeCalls.length > 0) {
      console.log("\nFound exchange contract calls:")
      console.log("─".repeat(50))

      exchangeCalls.forEach((call, index) => {
        console.log(`\nCall #${index + 1}:`)
        try {
          console.log(formatCallData(call, exchangeInterface, facetInterfaces))

          if (call.revertReason) {
            console.log("\nReverted with:", call.revertReason)
          }

          if (taskArgs.showCalldata) {
            console.log("\nRaw calldata:")
            console.log(call.input)
          }
        } catch (e) {
          console.log("Could not decode call data")
          if (call.revertReason) {
            console.log("Reverted with:", call.revertReason)
          }
        }
        console.log("─".repeat(50))
      })
    } else {
      console.log("No calls to exchange contract found in transaction")
    }
  })

task("decode-calldata", "Decode and format calldata for exchange contract")
  .addParam("calldata", "Calldata in hex string format")
  .setAction(async (taskArgs, hre) => {
    // Load GRVTExchange artifact and create interface
    const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
    const exchangeInterface = new Interface(exchangeArtifact.abi)

    // Load all facet interfaces
    const facetInterfaces = new Map<string, Interface>()
    for (const facetInfo of ExchangeFacetInfos) {
      try {
        const facetArtifact = await hre.artifacts.readArtifact(facetInfo.interface)
        facetInterfaces.set(facetInfo.facet, new Interface(facetArtifact.abi))
      } catch (e) {
        console.warn(`Warning: Could not load interface for ${facetInfo.interface}`)
      }
    }

    const mockCall: CallTrace = {
      from: "0x0000000000000000000000000000000000000000",
      to: "0x0000000000000000000000000000000000000000",
      input: taskArgs.calldata
    }

    try {
      console.log("\nDecoded calldata:")
      console.log("─".repeat(50))
      console.log(formatCallData(mockCall, exchangeInterface, facetInterfaces))
      console.log("─".repeat(50))
    } catch (e) {
      console.log("Could not decode calldata:", (e as Error).message)
    }
  })
