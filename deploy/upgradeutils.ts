import * as hre from "hardhat"
import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import { ethers } from "ethers"
import { getWallet, verifyEnoughBalance, DeployContractOptions } from "./utils"
import "@matterlabs/hardhat-zksync-upgradable"

export const deployContractUpgradable = async (
  contractArtifactName: string,
  initializationVariables?: any[],
  options?: DeployContractOptions
) => {
  const contractName = contractArtifactName
  console.log("Deploying " + contractName + "...")
  const log = (message: string) => {
    if (!options?.silent) console.log(message)
  }

  log(`\nStarting deployment process of "${contractArtifactName}"...`)

  const zkWallet = options?.wallet ?? getWallet()
  const deployer = new Deployer(hre, zkWallet)
  const contract = await deployer.loadArtifact(contractArtifactName).catch((error) => {
    if (error?.message?.includes(`Artifact for contract "${contractArtifactName}" not found.`)) {
      console.error(error.message)
      throw `⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`
    } else {
      throw error
    }
  })

  const chainId = hre.network.config.chainId
  // only chainID 324 and 280 are supported to estimate gas for proxies
  //   if (chainId != undefined && (chainId == 324 || chainId == 280)) {
  //     // Estimate contract deployment fee
  //     const deploymentFee = await hre.zkUpgrades.estimation.estimateGasProxy(deployer, contract, [], {
  //       kind: "transparent",
  //     })
  //     log(`Estimated deployment cost: ${ethers.formatEther(deploymentFee)} ETH`)

  //     // Check if the wallet has enough balance
  //     await verifyEnoughBalance(zkWallet, deploymentFee)
  //   }

  // Deploy the contract to zkSync via proxy
  const proxiedContract = await hre.zkUpgrades.deployProxy(deployer.zkWallet, contract, [initializationVariables], {
    initializer: "initialize",
  })
  await proxiedContract.waitForDeployment()

  // const proxiedContract = await deployer.deploy(contract, constructorArguments)
  const address = await proxiedContract.getAddress()
  const constructorArgs = proxiedContract.interface.encodeDeploy(initializationVariables)
  const fullContractSource = `${contract.sourceName}:${contract.contractName}`
  console.log(contractArtifactName + " deployed to:", address)

  // Display contract deployment info
  log(`\n"${contractArtifactName}" was successfully deployed:`)
  log(` - Contract address: ${address}`)
  log(` - Contract source: ${fullContractSource}`)
  log(` - Encoded constructor arguments: ${constructorArgs}\n`)

  return proxiedContract
}

export const upgradeTransparentUpgradeableProxy = async (
  upgradeContractArtifactName: string,
  proxyAddress: string,
  options?: DeployContractOptions
) => {
  const contractName = upgradeContractArtifactName
  console.log("Deploying " + contractName + "...")
  const log = (message: string) => {
    if (!options?.silent) console.log(message)
  }

  log(`\nStarting upgrade process of "${upgradeContractArtifactName}"...`)

  const zkWallet = options?.wallet ?? getWallet()
  const deployer = new Deployer(hre, zkWallet)
  const contractV2 = await deployer.loadArtifact(upgradeContractArtifactName).catch((error) => {
    if (error?.message?.includes(`Artifact for contract "${upgradeContractArtifactName}" not found.`)) {
      console.error(error.message)
      throw `⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`
    } else {
      throw error
    }
  })

  await hre.zkUpgrades.upgradeProxy(deployer.zkWallet, proxyAddress, contractV2)
}
