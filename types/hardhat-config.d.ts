import "hardhat/types/config"

declare module "hardhat/types/config" {
  interface HardhatUserConfig {
    contractAddresses?: {
      exchange?: {
        [network: string]: string;
      };
    };
  }
}