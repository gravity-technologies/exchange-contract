import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import GRVTBridgeProxy from "./GRVTBridgeProxy";


const GRVTTransactionFilterer = buildModule("GRVTTransactionFilterer", (m) => {
    const l1SharedBridge = m.getParameter("l1SharedBridge");
    const l2Bridge = m.getParameter("l2Bridge");
    const ownerAddress = m.getParameter("ownerAddress");
    const upgradableProxyAdminOwnerAddress = m.getParameter("upgradableProxyAdminOwnerAddress");

    const { bridgeProxy } = m.useModule(GRVTBridgeProxy);

    const txFiltererImpl = m.contract("GRVTTransactionFilterer");
    const txFilterer = m.contract("TransparentUpgradeableProxy", [
        txFiltererImpl,
        upgradableProxyAdminOwnerAddress,
        m.encodeFunctionCall(txFiltererImpl, "initialize", [
            l1SharedBridge,
            l2Bridge,
            bridgeProxy,
            ownerAddress
        ]),
    ], {});

    const proxyAdminAddress = m.readEventArgument(
        txFilterer,
        "AdminChanged",
        "newAdmin"
    );

    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

    return { proxyAdmin, txFilterer };
});

export default GRVTTransactionFilterer;
