import { task } from "hardhat/config"
import { getExchangeAddress } from "./utils"

const contractName = "GRVTExchange"


task("force-import", "Force import a proxy or implementation contract")
    .setAction(async (_, hre) => {
        const address = getExchangeAddress(hre)

        if (!address) {
            throw new Error(`No exchange address found in config for network ${hre.network.name}`)
        }

        const factory = await hre.ethers.getContractFactory(contractName);

        try {
            const contract = await hre.upgrades.forceImport(address, factory as any, { kind: 'transparent' });
            console.log(`Successfully imported ${contractName} at address ${address}`);
            console.log("Contract instance:", contract.address);
        } catch (error) {
            console.error("Error during force import:", error);
        }
    });

task("validate-upgrade", "Validate an upgrade for a proxy contract")
    .setAction(async (_, hre) => {
        const address = getExchangeAddress(hre)

        console.log("Validating upgrade...");
        console.log("Proxy address:", address);

        const factory = await hre.ethers.getContractFactory(contractName);

        try {
            await hre.upgrades.validateUpgrade(address, factory as any);

            console.log("Upgrade validated successfully.");
        } catch (error) {
            console.error("Error validating upgrade:", error);
        }
    });