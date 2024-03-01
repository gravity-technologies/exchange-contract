import * as fs from "fs"

// A Test is a sequence of test cases
export type Test = TestCase[]

export interface TestCase {
  // Name of the test case
  name: string
  // A test case is a sequence of test steps
  steps: TestStep[]
}

// A test step is a transaction to be executed and the expected result
export interface TestStep {
  // The time at which the transaction is executed (if left blank, its value is the same as the previous test step)

  // The function abi encoded transaction to be executed
  tx_data: string

  // The expected result of running the transaction
  ret: string

  // List of expectations to be executed after the transaction is executed
  expectations: Expectation[]
}

export interface Expectation {
  // Add should states here
}

export function parseTestsFromFile(filePath: string): TestCase[] {
  try {
    // Read the JSON file
    const data = fs.readFileSync(filePath, "utf8")

    // Parse the JSON data into an array of Test objects
    try {
      const tests = JSON.parse(data) as TestCase[]
      return tests
    } catch (error) {
      console.error("Failed to parse JSON:", error)
      return []
    }
  } catch (err) {
    console.log(`Error reading file from disk: ${err}`)
    return []
  }
}

export function loadTestFilesFromDir(dir: string): string[] {
  return fs.readdirSync(dir).map((file) => `${file}`)
}
