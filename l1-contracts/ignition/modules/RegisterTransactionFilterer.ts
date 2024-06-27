import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import GRVTTransactionFilterer from "./GRVTTransactionFilterer";
import { ethers } from "ethers";

const RegisterTransactionFilterer = buildModule("RegisterTransactionFilterer", (m) => {
    const governanceAddress = m.getParameter("governanceAddress");
    const diamondProxyAddress = m.getParameter("diamondProxyAddress");

    const { txFilterer } = m.useModule(GRVTTransactionFilterer);

    const governance = m.contractAt("IGovernance", governanceAddress);
    const diamondProxy = m.contractAt("IAdmin", diamondProxyAddress);

    const operation = {
        calls: [
            {
                target: governanceAddress,
                value: 0,
                data: m.encodeFunctionCall(diamondProxy, "setTransactionFilterer", [
                    txFilterer
                ])
            }
        ],
        predecessor: ethers.ZeroHash,
        salt: ethers.hexlify(ethers.randomBytes(32)),
    }

    const scheduleTransparentCall = m.call(
        governance,
        "scheduleTransparent",
        [operation, 0]
    )
    m.call(governance, "execute", [operation], {
        after: [scheduleTransparentCall]
    })

    return {};
});

export default RegisterTransactionFilterer;
