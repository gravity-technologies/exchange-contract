# GRVT Exchange Smart Contract

## Project Layout

- `/contracts`: Contains solidity smart contracts.
- `/deploy`: Scripts for contract deployment and interaction.
- `/test`: Test files.
- `hardhat.config.ts`: Configuration settings.

## Dependencies

- Install [era test node](https://docs.zksync.io/build/test-and-debug/era-test-node.html#understanding-the-in-memory-node). To test your installation, run `era_test_node run`.
- Install [consensys surya](https://github.com/ConsenSys/surya?tab=readme-ov-file) for static analysis of code like drawing inhetittance graph. (Optional)

## How to Use

- `era_test_node run`: run zkSync Era In-memory node locally, (alternative is to run `yarn hardhat node-zksync`)
- `yarn compile`: Compiles contracts.
- `yarn deploy:upgradable`: Deploys `GRVTExchange.sol` using the [transparent proxy pattern](https://blog.openzeppelin.com/the-transparent-proxy-pattern).
- `yarn test`: Tests the contracts.

Note: Both `npm run deploy` and `npm run interact` are set in the `package.json`. You can also run your files directly, for example: `npx hardhat deploy-zksync --script deploy.ts`

## Static Analysis

- `yarn draw`: draw the inherittance graph using the surya consensys module
  ![GRVTExchange Logo](GRVTExchange.png)

### Environment Settings

To keep private keys safe, this project pulls in environment variables from `.env` files. Primarily, it fetches the wallet's private key.

Rename `.env.example` to `.env` and fill in your private key:

```
WALLET_PRIVATE_KEY=your_private_key_here...
```

### Network Support

`hardhat.config.ts` comes with a list of networks to deploy and test contracts. Add more by adjusting the `networks` section in the `hardhat.config.ts`. To make a network the default, set the `defaultNetwork` to its name. You can also override the default using the `--network` option, like: `hardhat test --network dockerizedNode`.

## Notes

This project was scaffolded with [zksync-cli](https://github.com/matter-labs/zksync-cli).
