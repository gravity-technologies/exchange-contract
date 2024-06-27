const ethers = require("ethers")
const fs = require("fs")
const { BigNumber } = require("ethers")

function loadABI(artifactPath) {
  try {
    const artifactData = fs.readFileSync(artifactPath, "utf8")
    const artifact = JSON.parse(artifactData)
    return artifact.abi
  } catch (error) {
    console.error("Error loading ABI:", error)
    throw error // Re-throw the error to handle it at the calling level
  }
}

function decodeFunctionCall(abi, hexData) {
  // Create an ethers.utils.Interface instance
  const iface = new ethers.utils.Interface(abi)

  try {
    // Decode the function data
    const decodedData = iface.decodeFunctionData(iface.getFunction(hexData.slice(0, 8)), hexData.slice(8))

    // Convert decoded data to desired output format
    function convertToDict(data, names) {
      const result = {}
      for (let i = 0; i < names.length; i++) {
        const name = names[i]
        const value = data[i]
        if (Array.isArray(value)) {
          result[name] = convertToDict(value, names[i + 1])
          i++ // Skip the nested names
        } else {
          result[name] = value
        }
      }
      return result
    }

    // Get function signature and parameters
    const functionFragment = iface.getFunction(hexData.slice(0, 8))
    const parameters = functionFragment.inputs

    // Convert parameters to desired output format
    const output = convertToDict(
      decodedData,
      parameters.map((p) => p.name)
    )

    console.log(JSON.stringify(output, null, 2))
  } catch (error) {
    console.error("Error decoding transaction data:", error)
  }
}

const artifactPath = "./artifacts-zk/contracts/exchange/GRVTExchange.sol/GRVTExchange.json"
const abi = loadABI(artifactPath)
const encodedData =
  "0x86db00e100000000000000000000000000000000000000000000000017e6380bdff2141e0000000000000000000000000000000000000000000000000000000000019e27000000000000000000000000cf1bafd3ca7110dcf50a9b723f2159f9adedd7c7000000000000000000000000cf1bafd3ca7110dcf50a9b723f2159f9adedd7c7d9a6e27e36cbe9b66e2a0d41f4859d68565f21d52fec072316e59ee67eddee7d1e6498baf067e28826dd6e9765ff975090a64cd1c5be4e4f2ca8f1b7ac2c3c88000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000017e6869f03795a00000000000000000000000000000000000000000000000000000000007b4de7a8"
const decodedResult = decodeFunctionCall(abi, encodedData)
console.log(decodedResult)
