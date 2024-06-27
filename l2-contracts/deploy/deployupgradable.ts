import * as fs from "fs"
import { ContractName } from "./contract"
import { deployContractUpgradable } from "./utils"

// Deploy Upgradable Script
export default async function () {
  const contractArtifactName = ContractName
  await deployContractUpgradable(contractArtifactName)
}
