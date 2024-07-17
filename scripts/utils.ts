// hardhat import should be the first import in the file
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { ethers } from "ethers";
import type { BytesLike } from "ethers";

import { Interface } from "ethers/lib/utils";

import { Provider as ZkSyncProvider } from 'zksync-ethers';
import { IBridgehubFactory } from "../lib/era-contracts/l1-contracts/typechain/IBridgehubFactory";
import { IERC20Factory } from "zksync-web3/build/typechain";

import { hashBytecode } from "zksync-web3/build/src/utils";
import { HardhatRuntimeEnvironment, HttpNetworkConfig, Network, NetworkConfig, NetworksConfig } from "hardhat/types";
import { Address } from "zksync-ethers/build/src/types";


export const GAS_MULTIPLIER = 1;
const CREATE2_PREFIX = ethers.utils.solidityKeccak256(["string"], ["zksyncCreate2"]);

// eslint-disable-next-line @typescript-eslint/no-var-requires
export const REQUIRED_L2_GAS_PRICE_PER_PUBDATA = require("../lib/era-contracts/SystemConfig.json").REQUIRED_L2_GAS_PRICE_PER_PUBDATA;
export const ADDRESS_ONE = "0x0000000000000000000000000000000000000001";
const DEPLOYER_SYSTEM_CONTRACT_ADDRESS = "0x0000000000000000000000000000000000008006";

export function computeL2Create2Address(
  deployerAddress: Address,
  bytecode: BytesLike,
  constructorInput: BytesLike,
  create2Salt: BytesLike
) {
  const senderBytes = ethers.utils.hexZeroPad(deployerAddress, 32);
  const bytecodeHash = hashBytecode(bytecode);
  const constructorInputHash = ethers.utils.keccak256(constructorInput);

  const data = ethers.utils.keccak256(
    ethers.utils.concat([CREATE2_PREFIX, senderBytes, create2Salt, bytecodeHash, constructorInputHash])
  );

  return ethers.utils.hexDataSlice(data, 12);
}

export async function create2DeployFromL1NoFactoryDeps(
  hre: HardhatRuntimeEnvironment,
  chainId: ethers.BigNumberish,
  bridgehubAddress: string,
  l1SharedBridgeAddress: string,
  wallet: ethers.Wallet,
  bytecode: ethers.BytesLike,
  constructor: ethers.BytesLike,
  create2Salt: ethers.BytesLike,
  l2GasLimit: ethers.BigNumberish,
  gasPrice?: ethers.BigNumberish,
) {
  const bridgehub = IBridgehubFactory.connect(bridgehubAddress, wallet);

  const deployerSystemContracts = new Interface(hre.artifacts.readArtifactSync("IContractDeployer").abi);
  const bytecodeHash = hashBytecode(bytecode);
  const calldata = deployerSystemContracts.encodeFunctionData("create2", [create2Salt, bytecodeHash, constructor]);
  gasPrice ??= await bridgehub.provider.getGasPrice();
  const expectedCost = await bridgehub.l2TransactionBaseCost(
    chainId,
    gasPrice,
    l2GasLimit,
    REQUIRED_L2_GAS_PRICE_PER_PUBDATA
  );

  const baseTokenAddress = await bridgehub.baseToken(chainId);
  const baseToken = IERC20Factory.connect(baseTokenAddress, wallet);

  const tx = await baseToken.approve(l1SharedBridgeAddress, expectedCost);
  await tx.wait();

  return await bridgehub.requestL2TransactionDirect(
    {
      chainId,
      l2Contract: DEPLOYER_SYSTEM_CONTRACT_ADDRESS,
      mintValue: expectedCost,
      l2Value: 0,
      l2Calldata: calldata,
      l2GasLimit,
      l2GasPerPubdataByteLimit: REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
      factoryDeps: [],
      refundRecipient: wallet.address,
    },
  );
}

const SUPPORTED_L1_TESTNETS = ['mainnet', 'rinkeby', 'ropsten', 'kovan', 'goerli', 'sepolia'];

export function createProviders(
  networks: NetworksConfig,
  network: Network
): {
  l1Provider: ethers.providers.BaseProvider;
  l2Provider: ZkSyncProvider;
} {
  const networkName = network.name;

  if (!network.zksync) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'zksync' flag set to 'true'.`
    );
  }

  const networkConfig = network.config;

  if (!isHttpNetworkConfig(networkConfig)) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'url' specified.`
    );
  }

  if (networkConfig.ethNetwork === undefined) {
    throw new Error(
      `Only deploying to zkSync network is supported.\nNetwork '${networkName}' in 'hardhat.config' needs to have 'ethNetwork' (layer 1) specified.`
    );
  }

  let l1Provider, l2Provider;
  const ethNetwork = networkConfig.ethNetwork;

  if (isValidEthNetworkURL(ethNetwork)) {
    l1Provider = new ethers.providers.JsonRpcProvider(ethNetwork);
  } else if (ethNetwork in networks && isHttpNetworkConfig(networks[ethNetwork])) {
    l1Provider = new ethers.providers.JsonRpcProvider((networks[ethNetwork] as HttpNetworkConfig).url);
  } else {
    throw new Error(
      `Failed to resolve ethNetwork.\nNetwork '${networkName}' in 'hardhat.config' needs to have a valid 'ethNetwork' (layer 1) specified.`
    );
  }

  l2Provider = new ZkSyncProvider((network.config as HttpNetworkConfig).url);

  return { l1Provider, l2Provider };
}

export function isHttpNetworkConfig(networkConfig: NetworkConfig): networkConfig is HttpNetworkConfig {
  return 'url' in networkConfig;
}

export function isValidEthNetworkURL(string: string) {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return false;
  }
}