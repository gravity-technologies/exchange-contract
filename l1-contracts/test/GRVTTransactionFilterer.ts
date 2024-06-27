import hre from "hardhat";
import { expect } from "chai";
import { ethers } from "ethers";

import { IL2Bridge__factory } from "../typechain-types/factories/contracts/interfaces/IL2Bridge__factory";

describe("GRVTTransactionFilterer", function () {
    async function deployGRVTTransactionFiltererFixture() {
        const [owner, rando, l1SharedBridge, l2Bridge, grvtBridgeProxy] = await hre.ethers.getSigners();

        const grvtTransactionFiltererImplFactory = await hre.ethers.getContractFactory("GRVTTransactionFilterer");
        const grvtTransactionFiltererFactory = await hre.upgrades.deployProxy(grvtTransactionFiltererImplFactory, [
            l1SharedBridge.address,
            l2Bridge.address,
            grvtBridgeProxy.address,
            owner.address
        ]);
        const grvtTransactionFilterer = await grvtTransactionFiltererFactory.waitForDeployment();

        return {
            grvtTransactionFilterer,
            owner,
            rando,
            l1SharedBridgeAddress: l1SharedBridge.address,
            l2BridgeAddress: l2Bridge.address,
            grvtBridgeProxyAddress: grvtBridgeProxy.address
        };
    }

    describe("Deployment", function () {
        it("Should set the right initial values", async function () {
            const { grvtTransactionFilterer, owner, l1SharedBridgeAddress, l2BridgeAddress } = await deployGRVTTransactionFiltererFixture();
            expect(await grvtTransactionFilterer.owner()).to.equal(owner.address);
            expect(await grvtTransactionFilterer.l1SharedBridge()).to.equal(l1SharedBridgeAddress);
            expect(await grvtTransactionFilterer.l2Bridge()).to.equal(l2BridgeAddress);
        })
    });

    describe("Transaction filtering", function () {
        it("Should allow a qualified transaction to pass", async function () {
            const { grvtTransactionFilterer, rando, l1SharedBridgeAddress, l2BridgeAddress, grvtBridgeProxyAddress } = await deployGRVTTransactionFiltererFixture();
            expect(await grvtTransactionFilterer.isTransactionAllowed(
                l1SharedBridgeAddress,
                l2BridgeAddress,
                0,
                0,
                await getDepositL2Calldata(grvtBridgeProxyAddress, rando.address, rando.address, 100),
                hre.ethers.ZeroAddress
            )).to.equal(true);
        })

        it("Should reject transaction with l1 sender != grvtBridgeProxyAddress", async function () {
            const { grvtTransactionFilterer, rando, l1SharedBridgeAddress, l2BridgeAddress } = await deployGRVTTransactionFiltererFixture();
            expect(await grvtTransactionFilterer.isTransactionAllowed(
                l1SharedBridgeAddress,
                l2BridgeAddress,
                0,
                0,
                await getDepositL2Calldata(rando.address, rando.address, rando.address, 100),
                hre.ethers.ZeroAddress
            )).to.equal(false);
        })

        it("Should reject transaction with tx sender != l1SharedBridgeAddress", async function () {
            const { grvtTransactionFilterer, rando, l2BridgeAddress, grvtBridgeProxyAddress } = await deployGRVTTransactionFiltererFixture();
            expect(await grvtTransactionFilterer.isTransactionAllowed(
                rando.address,
                l2BridgeAddress,
                0,
                0,
                await getDepositL2Calldata(grvtBridgeProxyAddress, rando.address, rando.address, 100),
                hre.ethers.ZeroAddress
            )).to.equal(false);
        })

        it("Should reject transaction with l2Contract != l2BridgeAddress", async function () {
            const { grvtTransactionFilterer, rando, l1SharedBridgeAddress, grvtBridgeProxyAddress } = await deployGRVTTransactionFiltererFixture();
            expect(await grvtTransactionFilterer.isTransactionAllowed(
                l1SharedBridgeAddress,
                rando.address,
                0,
                0,
                await getDepositL2Calldata(grvtBridgeProxyAddress, rando.address, rando.address, 100),
                hre.ethers.ZeroAddress
            )).to.equal(false);
        })


        it("Should reject transaction with l2Calldata with a selector that's not finalizeDeposit", async function () {
            const { grvtTransactionFilterer, rando, l1SharedBridgeAddress, l2BridgeAddress, grvtBridgeProxyAddress } = await deployGRVTTransactionFiltererFixture();
            const calldata = await getDepositL2Calldata(grvtBridgeProxyAddress, rando.address, rando.address, 100);
            const modifiedCalldata = "0x00000000" + calldata.slice(10); // selector is not finalizeDeposit
            expect(await grvtTransactionFilterer.isTransactionAllowed(
                l1SharedBridgeAddress,
                l2BridgeAddress,
                0,
                0,
                modifiedCalldata,
                hre.ethers.ZeroAddress
            )).to.equal(false);
        })

        it("Should reject transaction with invalid calldata", async function () {
            const { grvtTransactionFilterer, rando, l1SharedBridgeAddress, l2BridgeAddress, grvtBridgeProxyAddress } = await deployGRVTTransactionFiltererFixture();
            const calldata = await getDepositL2Calldata(grvtBridgeProxyAddress, rando.address, rando.address, 100);
            const modifiedCalldata = calldata.slice(0, 2 + 8 + 64 * 4); // last field truncated

            // there isn't a way to catch abi.decode error in solidity, so can only revert in this case
            await expect(grvtTransactionFilterer.isTransactionAllowed(
                l1SharedBridgeAddress,
                l2BridgeAddress,
                0,
                0,
                modifiedCalldata,
                hre.ethers.ZeroAddress
            )).to.be.revertedWithoutReason();
        })
    });

    describe("Set variables", function () {
        it("Should transfer the owner if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            await grvtTransactionFilterer.transferOwnership(rando.address);
            expect(await grvtTransactionFilterer.owner()).to.equal(rando.address);
        })

        it("Should set L1 shared bridge if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            await grvtTransactionFilterer.setL1SharedBridge(rando.address);
            expect(await grvtTransactionFilterer.l1SharedBridge()).to.equal(rando.address);
        })

        it("Should set L2 bridge if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            await grvtTransactionFilterer.setL2Bridge(rando.address);
            expect(await grvtTransactionFilterer.l2Bridge()).to.equal(rando.address);
        })

        it("Should fail to transfer the owner if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            const grvtTransactionFiltererByRando = grvtTransactionFilterer.connect(rando) as ethers.Contract;
            await expect(grvtTransactionFiltererByRando.transferOwnership(rando.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        })

        it("Should fail to set L1 shared bridge if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            const grvtTransactionFiltererByRando = grvtTransactionFilterer.connect(rando) as ethers.Contract;
            await expect(grvtTransactionFiltererByRando.setL1SharedBridge(rando.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        })

        it("Should fail to set L2 bridge if the caller is the owner", async function () {
            const { grvtTransactionFilterer, rando } = await deployGRVTTransactionFiltererFixture();
            const grvtTransactionFiltererByRando = grvtTransactionFilterer.connect(rando) as ethers.Contract;
            await expect(grvtTransactionFiltererByRando.setL2Bridge(rando.address)).to.be.revertedWith(
                "Ownable: caller is not the owner"
            );
        })
    });
});

/**
 * Function to get the L2 deposit calldata
 * 
 * @param l1Sender - The L1 sender address
 * @param l2Receiver - The L2 receiver address
 * @param l1Token - The L1 token address
 * @param amount - The amount to deposit
 * @returns - The calldata for the finalizeDeposit function
 */
async function getDepositL2Calldata(
    l1Sender: string,
    l2Receiver: string,
    l1Token: string,
    amount: ethers.BigNumberish
) {
    const IL2BridgeInterface = IL2Bridge__factory.createInterface()

    const calldata = IL2BridgeInterface.encodeFunctionData(
        // gettersData can be an empty bytes array as it is not checked
        "finalizeDeposit", [l1Sender, l2Receiver, l1Token, amount, "0x"]);

    return calldata;
}