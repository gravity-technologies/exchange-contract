import { task } from "hardhat/config"

import { Contract, ethers } from "ethers"
import {
    createProviders,
    generateDiamondCutDataFromDiff,
    getLocalFacetInfo,
    getOnChainFacetInfo,
} from "./utils"
import { hashBytecode } from "zksync-web3/build/src/utils"
import { ExchangeFacetInfos } from "./diamond-info"

task("diff-diamond-facets", "diff diamond facets")
    .addParam("exchangeProxy", "exchangeProxy")
    .setAction(async (taskArgs, hre) => {
        const {
            exchangeProxy,
        } = taskArgs

        const { l2Provider } = createProviders(hre.config.networks, hre.network)
        const onChainFacetInfo = await getOnChainFacetInfo(hre, exchangeProxy, l2Provider)

        console.log("Facets: ", onChainFacetInfo)

        const localFacetInfo = await getLocalFacetInfo(hre)

        console.log("Local facets: ", localFacetInfo)

        const { add, replace, remove, facetsToDeploy } = generateDiamondCutDataFromDiff(onChainFacetInfo, localFacetInfo)

        console.log("Add actions: ", add)
        console.log("Replace actions: ", replace)
        console.log("Remove actions: ", remove)
        console.log("Facets to deploy: ", facetsToDeploy)
    })
