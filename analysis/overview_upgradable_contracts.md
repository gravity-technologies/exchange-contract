## Writing GRVT Exchange as an Upgradable Contract


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

### Initialization and Reinitialization
The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
case an upgrade adds a module that needs to be initialized.

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

Use of enums in our contracts
If the enum field lies within one and only one contract, it is absolutely safe for an upgrade. It is also safe if you can ensure that all contracts using the enum are redeployed altogether in case of modification
Our contracts use enums, so they must take care of the above
https://hackernoon.com/beware-the-solidity-enums-9v1qa31b2



### State Management


### Why we don’t use namespaced Storage Layout
ERC-7201: [Namespaced Storage Layout](https://eips.ethereum.org/EIPS/eip-7201) is another convention that can be used to avoid storage layout errors when modifying base contracts or when changing the inheritance order of contracts. This convention is used in the upgradeable variant of OpenZeppelin Contracts starting with version 5.0.
[Zksync uses Openzeppelin version 4.9.5](https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-upgradable.html#openzeppelin-version). 
