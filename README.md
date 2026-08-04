# GRVT Exchange Smart Contract

## Project Layout

This project is based on Foundry(Ethereum) + Hardhat(Zksync). Foundry is used mostly for unit testing while hardhat is used for testing, scripting and deployments. We use the [hardhat-foundry](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-foundry) plugin to support both frameworks.

- `/contracts`: Contains solidity smart contracts.
- `/deploy`: Scripts for contract deployment and interaction.
- `/test`: Test files. Files tested using foundry are under `test/foundry`
- `hardhat.config.ts`: Configuration settings.

## Getting Started

Clone the repo:

```
git clone https://github.com/gravity-technologies/dev-exchange-contract
```

## Dependencies

- `curl -L https://foundry.paradigm.xyz | bash` and `foundryup` to install foundry
- Install [Era Test Node](https://docs.zksync.io/build/test-and-debug/era-test-node.html#understanding-the-in-memory-node) from [this branch](https://github.com/gravity-technologies/era-test-node/tree/dz-free-pubdata). Build it with `cargo run --release -- run`, or copy the binary under `target/release/` to your PATH for convenience. To test your installation, run `era_test_node run`.

## Setup

```
yarn && yarn compile:era && yarn compile
```

## How to Use

- `era_test_node run`: Run zkSync Era In-memory node locally (an alternative is to run `yarn hardhat node-zksync`).
- `yarn compile`: Compiles contracts.
- `yarn test`: Tests the contracts using both forge and hardhat.

## RTF Test Fixtures

We verify equivalence with backend code using the RTF framework. To generate and use RTF test fixtures:

1. Run `make rtf` in `integration/bdd` and `backend/svc/risk` in the [platform repo](https://github.com/gravity-technologies/platform) to generate RTF test fixture JSON files.
2. Copy the generated fixture files to `test/engine/fixtures` in this repo.

## Running Tests

Tests require a local era test node running. Start it with `era_test_node run`, then:

```
npx hardhat test
```

## Important Temporary Note

### How to Access `era_test_node` with Contracts Larger Than the Limit

The current version of `era_test_node` supports a maximum contract size of 28kb. However, our contracts can be as large as 40kb. To test contracts of this size, you need to run tests against a specific version of `era_test_node` temporarily that supports Validiums.

You can use [this branch](https://github.com/matter-labs/era-test-node/tree/dz-free-pubdata) until we create a separate flag for validium mode.

To utilize this branch:

1. Build the `era_test_node` with:

   ```
   cargo build --release
   ```

2. Run it as an executable:
   ```
   ./target/release/era_test_node run
   ```
