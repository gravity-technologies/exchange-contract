import { ethers, Wallet as L1Wallet, providers as l1Providers } from "ethers";

import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet as L2Wallet, Provider as L2Provider } from 'zksync-ethers';

import { ADDRESS_ONE, create2DeployFromL1NoFactoryDeps, computeL2Create2Address, createProviders, } from "./utils";
import { task } from "hardhat/config";
import { applyL1ToL2Alias, hashBytecode } from "zksync-web3/build/src/utils";
import { Interface, keccak256 } from "ethers/lib/utils";

task("deploy-exchange-on-l2-through-l1", "Deploy exchange on L2 through L1")
    .addParam("l1DeployerPrivateKey", "l1DeployerPrivateKey")
    .addParam("l2OperatorPrivateKey", "l2OperatorPrivateKey")
    .addParam("governance", "governance")
    .addParam("bridgeHub", "bridgeHub")
    .addParam("l1SharedBridge", "l1SharedBridge")
    .addParam("chainId", "chainId")
    .addParam("saltPreImage", "saltPreImage")
    .setAction(async (taskArgs, hre) => {
        const {
            l1DeployerPrivateKey,
            l2OperatorPrivateKey,
            governance,
            bridgeHub,
            l1SharedBridge,
            chainId,
            saltPreImage,
        } = taskArgs;

        const { l1Provider, l2Provider } = createProviders(hre.config.networks, hre.network)
        const l2Operator = new L2Wallet(l2OperatorPrivateKey!, l2Provider);
        const l2Deployer = new Deployer(hre, l2Operator);

        const l1Deployer = new L1Wallet(l1DeployerPrivateKey!, l1Provider);

        const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(saltPreImage));
        console.log("CREATE2 salt: ", salt);
        console.log("CREATE2 salt preimage: ", saltPreImage);

        // deploy an instance of the exchange and TUP to L2 only to save the code on chain
        // actual deployment to be done through L1
        const exchangeArtifact = await l2Deployer.loadArtifact("GRVTExchange");
        const exchangeImpl = await l2Deployer.deploy(exchangeArtifact, []);
        const exchangeCodehash = hashBytecode(exchangeArtifact.bytecode);

        // TODO: add balance check
        // TODO: maintain local state of deployed contracts and information required for proofs

        const tupArtifact = await l2Deployer.loadArtifact("TransparentUpgradeableProxy")
        const tupInstance = await l2Deployer.deploy(tupArtifact, [
            exchangeImpl.address,
            ADDRESS_ONE,
            "0x"
        ]);
        const tupCodehash = hashBytecode(tupArtifact.bytecode);

        const exchangeImplConstructorData = ethers.utils.arrayify("0x");
        const expectedExchangeImplAddress = computeL2Create2Address(
            l1Deployer.address,
            exchangeArtifact.bytecode,
            exchangeImplConstructorData,
            salt
        )

        const exchangeProxyConstructorData = ethers.utils.arrayify(
            new ethers.utils.AbiCoder().encode(
                ["address", "address", "bytes"],
                [
                    expectedExchangeImplAddress,
                    applyL1ToL2Alias(governance),
                    new Interface(exchangeArtifact.abi).encodeFunctionData("initialize", [])
                ]
            )
        );

        const expectedExchangeProxyAddress = computeL2Create2Address(
            l1Deployer.address,
            tupArtifact.bytecode,
            exchangeProxyConstructorData,
            salt
        )

        console.log("L1 deployer address", l1Deployer.address);
        console.log("Exchange codehash: ", ethers.utils.hexlify(exchangeCodehash));
        console.log("TUP codehash: ", ethers.utils.hexlify(tupCodehash));
        console.log("Expected exchange impl address: ", expectedExchangeImplAddress);
        console.log("Expected exchange proxy address: ", expectedExchangeProxyAddress);

        // deploy exchange and proxy
        const exchangeImplDepTx = await create2DeployFromL1NoFactoryDeps(
            hre,
            chainId,
            bridgeHub,
            l1SharedBridge,
            l1Deployer,
            exchangeArtifact.bytecode,
            exchangeImplConstructorData,
            salt,
            1000000,
        )
        const exchangeImplDepTxReceipt = await exchangeImplDepTx.wait();
        console.log("Exchange impl deployment tx hash: ", exchangeImplDepTx.hash);
        console.log("Exchange impl deployment stauts: ", exchangeImplDepTxReceipt.status);

        const exchangeProxyDepTx = await create2DeployFromL1NoFactoryDeps(
            hre,
            chainId,
            bridgeHub,
            l1SharedBridge,
            l1Deployer,
            tupArtifact.bytecode,
            exchangeProxyConstructorData,
            salt,
            5000000,
        )
        const exchangeProxyDepTxReceipt = await exchangeProxyDepTx.wait();
        console.log("Exchange impl deployment tx hash: ", exchangeProxyDepTx.hash);
        console.log("Exchange impl deployment stauts: ", exchangeProxyDepTxReceipt.status);
    })