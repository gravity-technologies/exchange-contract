import { UpgradeContractName, ProxyAddress } from "./contract"
import { upgradeTransparentUpgradeableProxy } from "./utils"

// Deploy script to upgrade the contract
export default async function () {
  await upgradeTransparentUpgradeableProxy(UpgradeContractName, ProxyAddress)
}
