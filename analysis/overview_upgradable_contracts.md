## Writing GRVT Exchange as an Upgradable Contract

### Table of Contents

- [Overview](#overview)
- [Deploying and Upgrading Contract](#deploying-and-upgrading-contract)
- [Transparent Proxy Pattern](#transparent-proxy-pattern)
- [Upgrade Checklist](#upgrade-checklist)
  - [1. Initialization and Reinitialization](#1-initialization-and-reinitialization)
  - [2. Use of enums in our contracts](#2-use-of-enums-in-our-contracts)
  - [3. Use of constants in our contracts](#3-use-of-constants-in-our-contracts)
  - [4. State Management](#4-state-management)
- [Why we don’t use namespaced Storage Layout](#why-we-dont-use-namespaced-storage-layout)


### Overview
GRVTExchange is the only contract that we deloy as a part of our exchange and it is designed to be an upgradable contract. We use the [transparent proxy pattern](https://blog.openzeppelin.com/the-transparent-proxy-pattern).

![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/745c0f0a-ffb8-46e1-92cb-4fa139531551)

### Deploying and Upgrading Contract
There are two major commands to run 
1. `yarn deploy:upgradable` - deploys an upgradable contract for the first time and initializes the state.
2. `yarn deploy:upgrade` - upgrades the contract to a new implementation - proxy remains the same. We need to make sure to declare the correct `PROXY_ADDRESS` in our scripts.

![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/b4da7300-4f2a-4111-a6cb-be07927321ed)

### Transparent Proxy Pattern has three major contracts
As seen in the screenshot above, the three contracts are 
1. Implementation - changes across upgrades
2. Admin - stays the same across upgrades and the owner is the deployer of the first deployment. Only the admin can initiate future upgrades.
3. Transparent Proxy - stays the same across upgrades and holds the state

### Upgrade Checklist

### 1. Initialization and Reinitialization
The original `initialize` function cannot be called again, even after the contract is upgraded because this changes the state. If we have to reinitialize contracts, the initialization functions must use a version number. Once a version number is used, it is consumed and cannot be
reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
case an upgrade adds a module that needs to be initialized.

```
contract MyToken is ERC20Upgradeable {
     function initialize() initializer public {
         __ERC20_init("MyToken", "MTK");
     }
 }

 contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
     function initializeV2() reinitializer(2) public {
         __ERC20Permit_init("MyToken");
     }
 }
```

### 2. Use of enums in our contracts
If the enum field lies within one and only one contract, it is [safe for an upgrade](https://hackernoon.com/beware-the-solidity-enums-9v1qa31b2). It is also safe if you can ensure that all contracts using the enum are redeployed altogether in case of modification. Our contracts use enums, so they must take care of the above.


### 3. Use of constants in our contracts
Because the compiler does not reserve a storage slot for constants variables, and every occurrence is replaced by the respective constant expression. So it is [fine](https://ethereum.stackexchange.com/questions/150451/is-it-possible-to-change-a-constant-variable-value-when-using-upgradeable-patter) to declare and [add](https://github.com/OpenZeppelin/openzeppelin-sdk/pull/1036) constants.

### 4. State Management
State Management must be handled carefully when making upgrades and we dive deeper into the considerations [here](https://github.com/gravity-technologies/exchange-contract/blob/upgradable-docs/analysis/upgradable/state_management_upgradable_contracts.md).


### Why we don’t use namespaced Storage Layout
ERC-7201: [Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201) is another convention that can be used to avoid storage layout errors when modifying base contracts or when changing the inheritance order of contracts. This convention is used in the upgradeable variant of OpenZeppelin Contracts starting with version 5.0.
[Zksync uses Openzeppelin version 4.9.5](https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-upgradable.html#openzeppelin-version). 
