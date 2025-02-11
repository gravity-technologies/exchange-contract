import "hardhat/types/config"

declare module "hardhat/types/config" {
  interface HardhatUserConfig {
    contractAddresses?: {
      [network: string]: {
        exchange: string;
        multicall3: string;
      };
    };
  }
}