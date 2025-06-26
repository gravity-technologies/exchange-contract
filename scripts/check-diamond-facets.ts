import { task } from "hardhat/config"

import {
    createProviders,
    generateDiamondCutDataFromDiff,
    getLocalFacetInfo,
    getLocalFacetSigHashToSigMapping,
    getOnChainFacetInfo,
    validateHybridProxy,
    enrichDiamondCutActionsWithSignatures,
} from "./utils"

task("check-diamond-facets", "check diamond facets")
    .addParam("exchangeProxy", "exchangeProxy")
    .setAction(async (taskArgs, hre) => {
        const {
            exchangeProxy,
        } = taskArgs

        const { l2Provider } = createProviders(hre.config.networks, hre.network)
        const onChainFacetInfo = await getOnChainFacetInfo(hre, exchangeProxy, l2Provider)

        console.log("On-chain facets: ", onChainFacetInfo)

        const localFacetInfo = await getLocalFacetInfo(hre)
        const sigHashToSigMapping = await getLocalFacetSigHashToSigMapping(hre)

        console.log("Local facets: ", localFacetInfo)

        const diamondCutData = generateDiamondCutDataFromDiff(onChainFacetInfo, localFacetInfo)

        if (!await validateHybridProxy(hre, localFacetInfo)) {
            throw new Error("Invalid diamond cut data")
        }

        const enrichedDiamondCutData = await enrichDiamondCutActionsWithSignatures(
            diamondCutData,
            sigHashToSigMapping
        );

        console.log("Add actions: ", enrichedDiamondCutData.add)
        console.log("Replace actions: ", enrichedDiamondCutData.replace)
        console.log("Remove actions: ", enrichedDiamondCutData.remove)
        console.log("Facets to deploy: ", enrichedDiamondCutData.facetsToDeploy)
    })
