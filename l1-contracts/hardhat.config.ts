import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';

import { IGovernance__factory } from "./typechain-types/factories/contracts/interfaces/IGovernance__factory";
import { txConfirmation, generateSignature } from "./utils";
const config: HardhatUserConfig = {
  paths: {
    sources: "./contracts",
  },
  solidity: "0.8.20",
  networks: {
    localhost: {
      url: "http://localhost:8545",
      accounts: [
        "0xe131bc3f481277a8f73d680d9ba404cc6f959e64296e0914dded403030d4f705", // L1 operator, ETH & DAI rich
        "0x3eb15da85647edd9a1159a4a13b9e7c56877c4eb33f614546d4db06a51868b1c" // deployer
      ]
    }
  }
};

task("set-transaction-filterer", "Register the transaction filterer")
  .addParam("diamondProxyAddress", "The address of the diamond proxy")
  .addParam("txFiltererAddress", "The address of the transaction filterer")
  .addParam("governanceAddress", "The address of the governance contract")
  .setAction(async (taskArgs, hre) => {
    const { diamondProxyAddress, txFiltererAddress, governanceAddress } = taskArgs;

    const [operator] = await hre.ethers.getSigners();

    const hyperchainAbi = [
      "function setTransactionFilterer(address _transactionFilterer) external"
    ];

    // Set transaction filterer on the hyperchain
    const iface = new hre.ethers.Interface(hyperchainAbi);
    const calldata = iface.encodeFunctionData(
      "setTransactionFilterer", [txFiltererAddress]
    );

    const gov = IGovernance__factory.connect(governanceAddress, operator);
    const operation = {
      calls: [{ target: diamondProxyAddress, value: 0, data: calldata }],
      predecessor: hre.ethers.ZeroHash,
      salt: hre.ethers.hexlify(hre.ethers.randomBytes(32)),
    };

    const scheduleTx = await gov.scheduleTransparent(operation, 0);
    await scheduleTx.wait();
    console.log("Upgrade scheduled");

    const executeTX = await gov.execute(operation, { value: 0 });
    await executeTX.wait();
    console.log(
      "Upgrade with target: ",
      diamondProxyAddress
    );
  });

task("bridge-erc20", "Bridge ERC20 tokens")
  .addParam("token", "The token address", "0x70a0F165d6f8054d0d0CF8dFd4DD2005f0AF6B55")
  .addParam("amount", "The amount to bridge", "1000000000000000000")
  .addParam("deadline", "The deposit deadline", "2000000000")
  .addParam("bridgeProxyAddress", "The address of the bridge proxy")
  .setAction(async (taskArgs, hre) => {
    const { token, amount, bridgeProxyAddress, deadline } = taskArgs;
    const [operator] = await hre.ethers.getSigners();

    const tokenAbi = [
      "function approve(address spender, uint256 amount) external returns (bool)"
    ];

    const tokenContract = new hre.ethers.Contract(token, tokenAbi, operator);

    await txConfirmation(tokenContract.approve(bridgeProxyAddress, amount))
    console.log(
      `GRVTBridgeProxy approved to spend ${amount} tokens at ${token}: `);

    const bridgeProxy = await hre.ethers.getContractAt("GRVTBridgeProxy", bridgeProxyAddress);
    await (await bridgeProxy.addAllowedToken(token)).wait()
    console.log(`Allowed token ${token} added to GRVTBridgeProxy.`);

    const sig = await generateSignature({
      l1Sender: operator.address,
      l2Receiver: operator.address,
      l1Token: token,
      amount: amount,
      deadline: deadline,
      wallet: operator
    });

    console.log(
      "Bridge transaction: ",
      await (await bridgeProxy.deposit(operator.address, token, amount, deadline, sig.v, sig.r, sig.s, {
        value: hre.ethers.parseUnits("1", 18),
        gasLimit: 2900000
      })).wait()
    );
  });

export default config;
