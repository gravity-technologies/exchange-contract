import { task } from "hardhat/config"

import { ethers, Wallet as L1Wallet, providers as l1Providers, BigNumber, Contract } from "ethers"
import { Wallet as L2Wallet, Provider as L2Provider } from "zksync-ethers"
import {
    createProviders,
    getL1ToL2TxInfo,
    getBaseToken,
    getGovernanceCalldata,
    scheduleAndExecuteGovernanceOp,
    deployFromL1NoFactoryDepsNoConstructor,
    encodeTransparentProxyUpgradeToAndCall,
    generateDiamondCutDataForNewFacets,
    approveL1SharedBridgeIfNeeded,
    validateHybridProxy,
    getLocalFacetInfo,
} from "./utils"

import { applyL1ToL2Alias } from "zksync-web3/build/src/utils"

import { Deployer } from "@matterlabs/hardhat-zksync-deploy"

import { ExchangeFacetInfos } from "./diamond-info"
import { Interface } from "ethers/lib/utils"

task("migrate-diamond-through-l1-governance", "Migrate diamond through L1 governance")
    .addParam("chainId", "chainId")
    .addParam("l1DeployerPrivateKey", "l1DeployerPrivateKey")
    .addParam("l1GovernanceAdminPrivateKey", "l1GovernanceAdminPrivateKey")
    .addParam("l1NonProxyGovernanceAdminPrivateKey", "l1NonProxyGovernanceAdminPrivateKey")
    .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
    .addParam("bridgeHub", "bridgeHub")
    .addParam("l1SharedBridge", "l1SharedBridge")
    .addParam("governance", "governance")
    .addParam("nonProxyGovernance", "nonProxyGovernance")
    .addParam("exchangeProxy", "exchangeProxy")
    .addParam("saltPreImage", "saltPreImage")
    .setAction(async (taskArgs, hre) => {
        const {
            chainId,
            l1DeployerPrivateKey,
            l1GovernanceAdminPrivateKey,
            l1NonProxyGovernanceAdminPrivateKey,
            l2OperatorPrivateKey,
            bridgeHub,
            l1SharedBridge,
            governance: proxyGovernance,
            nonProxyGovernance,
            exchangeProxy,
            saltPreImage,
        } = taskArgs

        const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)
        const l2Operator = new L2Wallet(l2OperatorPrivateKey!, l2Provider)
        const l2Deployer = new Deployer(hre, l2Operator)

        const l1GovernanceAdmin = new L1Wallet(l1GovernanceAdminPrivateKey!, l1Provider)
        const l1NonProxyGovernanceAdmin = new L1Wallet(l1NonProxyGovernanceAdminPrivateKey!, l1Provider)

        const l1Deployer = new L1Wallet(l1DeployerPrivateKey!, l1Provider)

        const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(saltPreImage))
        console.log("CREATE2 salt: ", salt)
        console.log("CREATE2 salt preimage: ", saltPreImage)

        await approveL1SharedBridgeIfNeeded(chainId, bridgeHub, l1SharedBridge, l1Deployer)

        const artifactsToDeploy = [
            "GRVTExchange",
            "DiamondCutFacet",
            ...ExchangeFacetInfos.map(facetInfo => facetInfo.facet)
        ]

        const deployedContracts = new Map<string, string>();

        for (const artifactName of artifactsToDeploy) {
            const result = await deployFromL1NoFactoryDepsNoConstructor(
                hre,
                chainId,
                bridgeHub,
                l1SharedBridge,
                l1Deployer,
                l2Deployer,
                artifactName,
                salt
            );

            deployedContracts.set(artifactName, result.address);
        }

        const diamondCutInput: { address: string, abi: any[] }[] = [];
        for (const facetInfo of ExchangeFacetInfos) {
            const facetAbi = await hre.artifacts.readArtifact(facetInfo.interface);
            diamondCutInput.push({
                address: deployedContracts.get(facetInfo.facet)!,
                abi: facetAbi.abi
            });
        }

        const exchangeArtifact = await hre.artifacts.readArtifact("GRVTExchange")
        const exchangeInterface = new Interface(exchangeArtifact.abi)

        const grvtExchangeImplAddress = deployedContracts.get("GRVTExchange")!
        const diamondCutFacetAddress = deployedContracts.get("DiamondCutFacet")!

        const diamondCutData = await generateDiamondCutDataForNewFacets(diamondCutInput);
        if (!await validateHybridProxy(hre, await getLocalFacetInfo(hre))) {
            throw new Error("Invalid diamond cut data")
        }

        const exchangeContractAsDiamondCut = new Contract(
            exchangeProxy,
            (await hre.artifacts.readArtifact("IDiamondCut")).abi,
            l2Operator
        )

        const baseToken = await getBaseToken(chainId, bridgeHub, l1Provider)
        // schedule governance operation with 2 steps
        // approve l1SharedBridge to spend max amount of token
        // upgrade proxy to new target
        const gasPrice = await l1Provider.getGasPrice()
        const proxyGovernanceCalls = [
            {
                target: baseToken,
                data: new ethers.utils.Interface(["function approve(address,uint256)"]).encodeFunctionData("approve", [
                    l1SharedBridge,
                    ethers.constants.MaxUint256,
                ]),
                value: 0,
            },
            await getL1ToL2TxInfo(
                chainId,
                bridgeHub,
                exchangeProxy,
                await encodeTransparentProxyUpgradeToAndCall(
                    hre, grvtExchangeImplAddress,
                    exchangeInterface.encodeFunctionData("reinitializeMigrateDiamond", [
                        applyL1ToL2Alias(nonProxyGovernance),
                        diamondCutFacetAddress
                    ])),
                ethers.constants.AddressZero,
                gasPrice.mul(10000), // use high gas price for L2 transaction to ensure the transaction is included
                BigNumber.from(1000000),
                l1Provider
            ),
        ]

        const proxyGovOperation = {
            calls: proxyGovernanceCalls,
            predecessor: ethers.constants.HashZero,
            salt: salt, // use the same salt for both create 2 and governance operation
        }

        const { scheduleTxReceipt: proxyGovScheduleTxReceipt, executeTxReceipt: proxyGovExecuteTxReceipt } = await scheduleAndExecuteGovernanceOp(
            proxyGovernance,
            l1GovernanceAdmin,
            proxyGovOperation
        )

        console.log("Proxy governance operation schedule txhash: ", proxyGovScheduleTxReceipt.transactionHash)
        console.log("Proxy governance operation schedule status: ", proxyGovScheduleTxReceipt.status)

        console.log("Proxy governance operation execution txhash: ", proxyGovExecuteTxReceipt.transactionHash)
        console.log("Proxy governance operation execution status: ", proxyGovExecuteTxReceipt.status)

        console.log("Proxy governance calldata: ", await getGovernanceCalldata(proxyGovOperation, l1Provider))

        const nonProxyGovernanceCalls = [
            {
                target: baseToken,
                data: new ethers.utils.Interface(["function approve(address,uint256)"]).encodeFunctionData("approve", [
                    l1SharedBridge,
                    ethers.constants.MaxUint256,
                ]),
                value: 0,
            },
            await getL1ToL2TxInfo(
                chainId,
                bridgeHub,
                exchangeProxy,
                exchangeContractAsDiamondCut.interface.encodeFunctionData("diamondCut", [
                    diamondCutData,
                    ethers.constants.AddressZero,
                    "0x"
                ]),
                ethers.constants.AddressZero,
                gasPrice.mul(10000), // use high gas price for L2 transaction to ensure the transaction is included
                BigNumber.from(5000000),
                l1Provider
            ),
        ]

        const nonProxyGovOperation = {
            calls: nonProxyGovernanceCalls,
            predecessor: ethers.constants.HashZero,
            salt: salt, // use the same salt for both create 2 and governance operation
        }

        const { scheduleTxReceipt: nonProxyGovScheduleTxReceipt, executeTxReceipt: nonProxyGovExecuteTxReceipt } = await scheduleAndExecuteGovernanceOp(
            nonProxyGovernance,
            l1NonProxyGovernanceAdmin,
            nonProxyGovOperation
        )

        console.log("Non-proxy governance operation schedule txhash: ", nonProxyGovScheduleTxReceipt.transactionHash)
        console.log("Non-proxy governance operation schedule status: ", nonProxyGovScheduleTxReceipt.status)

        console.log("Non-proxy governance operation execution txhash: ", nonProxyGovExecuteTxReceipt.transactionHash)
        console.log("Non-proxy governance operation execution status: ", nonProxyGovExecuteTxReceipt.status)

        console.log("Non-proxy governance calldata: ", await getGovernanceCalldata(nonProxyGovOperation, l1Provider))
    })
