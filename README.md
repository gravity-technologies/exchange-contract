# GRVT Exchange Smart Contracts

## Project Structure
This project contains 3 modules:

- `./l1-contracts`: L1(Ethereum) contracts for native bridging
- `./l2-contracts`: L2(GRVT Hyperchain) GRVT exchange contracts

Notably the `l2-contracts` expects GRVT's fork of [era-contracts](https://github.com/gravity-technologies/era-contracts/tree/feat/convenient-bridging) for convenient bridging.

## Setup

- `curl -L https://foundry.paradigm.xyz | bash` and `foundryup` to install foundry

## Usage

You can run commands in each module from the project root with `yarn <l1|l2>`. For example, use `yarn l1 compile` to compile L1 contracts.

For detailed usage, please refer to the README.md file in each module([L1](./l1-contracts/README.md)|[L2](./l2-contracts/README.md)).