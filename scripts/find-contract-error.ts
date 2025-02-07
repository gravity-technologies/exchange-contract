import { task } from "hardhat/config"
import { createProviders } from "./utils"
import { Interface } from "ethers/lib/utils"

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

function findRevertInCalls(calls: CallTrace[] | undefined, exchangeAddr: string, includeContext = false): RevertContext | null {
  if (!calls) return null

  for (const call of calls) {
    // For multicall contracts, we need to look at their internal calls
    if (call.calls?.length) {
      let lastExchangeCall: CallTrace | undefined
      
      for (const innerCall of call.calls) {
        if (innerCall.to?.toLowerCase() === exchangeAddr.toLowerCase()) {
          if (innerCall.revertReason) {
            return {
              call: innerCall,
              previousCall: includeContext ? lastExchangeCall : undefined
            }
          }
          lastExchangeCall = innerCall
        }
        
        // Also check deeper calls
        const innerRevert = findRevertInCalls([innerCall], exchangeAddr, includeContext)
        if (innerRevert) return innerRevert
      }
    }
    
    // Direct call to exchange
    if (call.to?.toLowerCase() === exchangeAddr.toLowerCase() && call.revertReason) {
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

function formatCallData(call: CallTrace, exchangeInterface: Interface): string {
  try {
    const selector = call.input?.slice(0, 10)
    const functionFragment = exchangeInterface.getFunction(selector || "0x")
    const decodedData = call.input ? 
      exchangeInterface.decodeFunctionData(functionFragment, call.input) : null
    
    const args = decodedData ? parseArguments(functionFragment, decodedData) : null
    
    return `${functionFragment.name}(${args ? JSON.stringify(args, null, 2) : 'no args'})`
  } catch (e) {
    return call.input || 'no input'
  }
}

task("find-contract-error", "Find contract error in a specific transaction")
  .addParam("txHash", "Transaction hash to analyze")
  .addOptionalParam("exchangeAddr", "Address of the exchange contract (overrides config)")
  .addFlag("showCalldata", "Show raw calldata in output")
  .setAction(async (taskArgs, hre) => {
    // Get exchange address from param or config
    const exchangeAddr = taskArgs.exchangeAddr ||
      (hre.config as any).contractAddresses?.[hre.network.name]?.exchange

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

    const response = await l2Provider.send("debug_traceTransaction", [
      taskArgs.txHash,
      { tracer: "callTracer" }
    ])

    // Find revert in call tree, include context for assertion errors
    const revertContext = findRevertInCalls(
      [response], 
      exchangeAddr,
      true // Include context for all calls to help with debugging
    )

    if (revertContext) {
      const { call: revertCall, previousCall } = revertContext
      
      console.log("\nFound exchange contract error:")
      console.log("─".repeat(50))
      
      try {
        const selector = revertCall.input?.slice(0, 10)
        const functionFragment = exchangeInterface.getFunction(selector || "0x")
        const isAssertionError = functionFragment.name.startsWith('assert')

        if (previousCall && isAssertionError) {
          console.log("Previous successful call:")
          console.log(formatCallData(previousCall, exchangeInterface))
          console.log("─".repeat(50))
          console.log("\nFailed assertion:")
        }

        console.log(formatCallData(revertCall, exchangeInterface))
        console.log("─".repeat(50))
        console.log("\nRevert reason:", revertCall.revertReason)
        
        if (taskArgs.showCalldata) {
          console.log("─".repeat(50))
          console.log("\nRaw calldata:")
          console.log(revertCall.input)
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
