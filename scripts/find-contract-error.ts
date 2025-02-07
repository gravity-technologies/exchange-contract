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

function findRevertInCalls(calls: CallTrace[] | undefined, exchangeAddr: string): CallTrace | null {
  if (!calls) return null

  for (const call of calls) {
    // Check if this is a call to exchange contract with a revert reason
    if (
      call.to?.toLowerCase() === exchangeAddr.toLowerCase() && 
      call.revertReason
    ) {
      return call
    }

    // Recursively check inner calls
    const innerRevert = findRevertInCalls(call.calls, exchangeAddr)
    if (innerRevert) {
      return innerRevert
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

    // Make debug_traceTransaction request
    const response = await l2Provider.send("debug_traceTransaction", [
      taskArgs.txHash,
      { tracer: "callTracer" }
    ])

    // Find revert in call tree
    const revertCall = findRevertInCalls([response], exchangeAddr)

    if (revertCall) {
      console.log("Found exchange contract call with error:")
      console.log("Revert reason:", revertCall.revertReason)
      if (taskArgs.showCalldata) {
        console.log("Calldata:", revertCall.input)
      }
      const selector = revertCall.input?.slice(0, 10)
      
      try {
        // Get function name from selector
        const functionFragment = exchangeInterface.getFunction(selector || "0x")
        console.log("Method:", functionFragment.name)

        // Decode function arguments
        if (revertCall.input) {
          const decodedData = exchangeInterface.decodeFunctionData(
            functionFragment, 
            revertCall.input
          )
          
          // Convert and parse arguments using ABI information
          const args = parseArguments(functionFragment, decodedData)
          console.log("Arguments:", JSON.stringify(args, null, 2))
        }
      } catch (e) {
        console.log("Could not decode method name or arguments from calldata")
      }
    } else {
      console.log("No contract errors found in transaction")
    }
  })
