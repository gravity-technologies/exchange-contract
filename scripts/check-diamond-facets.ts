import { task } from "hardhat/config"

import {
    createProviders,
    generateDiamondCutDataFromDiff,
    getLocalFacetInfo,
    getOnChainFacetInfo,
    validateHybridProxy,
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

        console.log("Local facets: ", localFacetInfo)

        const diamondCutData = generateDiamondCutDataFromDiff(onChainFacetInfo, localFacetInfo)

        if (!await validateHybridProxy(hre, localFacetInfo)) {
            throw new Error("Invalid diamond cut data")
        }

        const { add, replace, remove, facetsToDeploy } = diamondCutData;

        console.log("Add actions: ", add)
        console.log("Replace actions: ", replace)
        console.log("Remove actions: ", remove)
        console.log("Facets to deploy: ", facetsToDeploy)
    })
