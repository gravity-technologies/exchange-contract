import { execSync } from "child_process"
import { Contract, ethers } from "ethers"
import path from "path"
import { L2TokenInfo } from "../../deploy/testutil"
import { LOCAL_RICH_WALLETS, deployContract, getWallet } from "../../deploy/utils"
import { L2SharedBridgeFactory } from "../../lib/era-contracts/l2-contracts/typechain/L2SharedBridgeFactory"
import { getDeployerWallet } from "../util"
import { generateDiamondCutData, validateDiamondCutData, FacetCutAction } from "../../scripts/utils"
import { Deployer } from "@matterlabs/hardhat-zksync-deploy"
import * as hre from "hardhat"
import { hashBytecode } from "zksync-web3/build/src/utils"
import { Interface } from "ethers/lib/utils"
import { ExchangeFacetInfos } from "../../scripts/diamond-info"
export async function setupTestEnvironment() {
  const w1 = getDeployerWallet()
  const exchangeContract = await deployContracts()
  const l2SharedBridgeAsL1Bridge = await setupL2SharedBridge(exchangeContract)

  return { exchangeContract, l2SharedBridgeAsL1Bridge, w1 }
}

async function deployContracts() {
  const deployerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey)
  const proxyAdminWallet = getWallet(LOCAL_RICH_WALLETS[3].privateKey)
  const deployOptions = { wallet: deployerWallet, silent: true, noVerify: true }

  const exchangeContractImpl = await deployContract("GRVTExchange", [], deployOptions)
  const rtfTestInitializeConfigSigner = "0xA08Ee13480C410De20Ea3d126Ee2a7DaA2a30b7D"

  const l2Deployer = new Deployer(hre, deployerWallet)
  const beaconProxyArtifact = await l2Deployer.loadArtifact("BeaconProxy")

  // just to register the bytecode
  const beacon = await deployContract("UpgradeableBeacon", [exchangeContractImpl.address], deployOptions)
  await deployContract("BeaconProxy", [beacon.address, "0x"], deployOptions)

  const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
  const exchangeInterface = new Interface(exchangeArtifact.abi)

  const exchangeContract = await deployContract("TransparentUpgradeableProxy", [
    exchangeContractImpl.address,
    proxyAdminWallet.address,
    exchangeInterface.encodeFunctionData("initialize", [
      deployerWallet.address,
      // deployer is also the chain submitter
      deployerWallet.address,
      rtfTestInitializeConfigSigner,
      deployerWallet.address,
      hashBytecode(beaconProxyArtifact.bytecode)
    ])

  ], deployOptions)

  const diamondCutFacet = await deployContract("DiamondCutFacet", [], deployOptions)

  const exchangeContractProxy = new Contract(
    exchangeContract.address,
    (await hre.artifacts.readArtifact("ITransparentUpgradeableProxy")).abi,
    proxyAdminWallet
  )

  await exchangeContractProxy.upgradeToAndCall(
    exchangeContractImpl.address,
    exchangeInterface.encodeFunctionData("reinitializeMigrateDiamond", [
      deployerWallet.address,
      diamondCutFacet.address
    ])
  )

  const diamondCutInput = [];
  for (const facetInfo of ExchangeFacetInfos) {
    const facetContract = await deployContract(facetInfo.facet, [], deployOptions);
    const facetAbi = await hre.artifacts.readArtifact(facetInfo.interface);
    diamondCutInput.push({
      address: facetContract.address,
      abi: facetAbi.abi
    });
  }

  const diamondCutData = await generateDiamondCutData(diamondCutInput, FacetCutAction.Add);

  if (!validateDiamondCutData(exchangeArtifact.abi, diamondCutData)) {
    throw new Error("Invalid diamond cut data")
  }

  const exchangeContractAsDiamondCut = new Contract(
    exchangeContract.address,
    (await hre.artifacts.readArtifact("IDiamondCut")).abi,
    deployerWallet
  )

  // Execute diamond cut to add all facet methods
  await exchangeContractAsDiamondCut.diamondCut(
    diamondCutData,
    ethers.constants.AddressZero, // No initialization
    "0x" // No initialization calldata
  );

  return new Contract(
    exchangeContract.address,
    (await hre.artifacts.readArtifact("IGRVTExchange")).abi,
    deployerWallet
  )
}

async function setupL2SharedBridge(exchangeContract: ethers.Contract) {
  const [deployerWallet, governorWallet, l1BridgeWallet] = LOCAL_RICH_WALLETS.slice(0, 3).map((w) =>
    getWallet(w.privateKey)
  )

  const result = execSync(
    [
      "npx",
      "hardhat",
      "deploy-erc20-test-setup",
      "--deployer-private-key",
      deployerWallet.privateKey,
      "--governor-private-key",
      governorWallet.privateKey,
      "--l1-bridge-private-key",
      l1BridgeWallet.privateKey,
      "--salt",
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test")),
    ].join(" "),
    { cwd: path.resolve("lib/era-contracts/l2-contracts"), stdio: "pipe" }
  )

  const l2SharedBridgeAddress = result.toString().trim()
  const l2SharedBridge = L2SharedBridgeFactory.connect(l2SharedBridgeAddress, deployerWallet)

  console.log(`Deployed L2SharedBridge at ${l2SharedBridgeAddress}`)
  for (const token in L2TokenInfo) {
    const tokenAddress = await l2SharedBridge.l2TokenAddress(L2TokenInfo[token].l1Token)
    console.log(`Token ${token} has L2 address ${tokenAddress}`)
  }

  await (await l2SharedBridge.setExchangeAddress(exchangeContract.address)).wait()

  return L2SharedBridgeFactory.connect(l2SharedBridgeAddress, l1BridgeWallet)
}
