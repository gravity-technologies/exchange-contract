## State Management for Upgradable Contracts

## Table of Contents

- [Overview](#overview)
- [Simple Example](#simple-example)
- [C3 Linearization of GRVTExchange Contract](#c3-linearization-of-grvtexchange-contract)
  - [Example of adding a new var in the base contract](#example-of-adding-a-new-var-in-the-base-contract)
- [GRVTExchange contract](#grvtexchange-contract)
  - [A. Expanding the State Struct](#a-expanding-the-state-struct)
    - [Experiment 1: Extending without using gaps](#experiment-1-extending-without-using-gaps)
    - [Experiment 2: Extending a new field of value type with gaps](#experiment-2-extending-a-new-field-of-value-type-with-gaps)
    - [Experiment 3: Extending with a struct field with gaps](#experiment-3-extending-with-a-struct-field-with-gaps)
    - [Conclusion](#conclusion)
  - [B. Expanding mappings from Value/Address Type => Structs](#b-expanding-mappings-from-valueaddress-type--structs)
    - [Experiment: Upgrading a contract by adding a field to a struct that is a value in one of the mappings](#experiment-upgrading-a-contract-by-adding-a-field-to-a-struct-that-is-a-value-in-one-of-the-mappings)
  - [C. Mappings from Enums => Structs](#c-mappings-from-enums--structs)
  - [D. Expanding Structs](#d-expanding-structs)
    - [Experiment 1: Expanding Struct without storage gaps](#experiment-1-expanding-struct-without-storage-gaps)
    - [Experiment 2: Expanding Struct with storage gaps](#experiment-2-expanding-struct-with-storage-gaps)
  - [E. Value Types](#e-value-types)


### Overview
C3 linearization is used in updating state in upgradable contracts to determine the order of state variables in the inheritance chain. In Solidity, when a contract inherits from multiple contracts, the ordering of state variables is determined by the C3-linearized order of contracts. This affects the storage layout and is crucial for ensuring that state variables are correctly initialized and accessed during contract upgrades. The C3 linearization order is used to avoid issues such as storage layout clashes and to maintain the integrity of the state variables during contract upgrades. The C3 linearization of our contracts are generated [here](https://github.com/gravity-technologies/exchange-contract/blob/upgradable-docs/analysis/upgradable/state_management_upgradable_contracts.md).


#### [Simple Example](https://ethereum.stackexchange.com/questions/63403/in-solidity-how-does-the-slot-assignation-work-for-storage-variables-when-there):

contract A is B, C, D {}
The Storage will be arranged like this:
```
Storage B;
Storage C;
Storage D;
Storage A;
```

Now, if you want to Add E to your already written contract (And not cause memory collisions), this is how you go about doing it.

```
Contract A2 is A, E { }
```

The storage will be arranged like this:

```
Storage B;
Storage C;
Storage D;
Storage A;
Storage E;
```
This will make it safe to upgrade.

If you do it the opposite way:

Contract A2 is E, A { }
E will be set on the top, and you will mess up the order of your storage slots.

```
Storage E;
Storage B;
Storage C;
Storage D;
Storage A;
```
### C3 Linearization of GRVTExchange Contract
GRVTExchange
  1. TradeContract
  2. TransferContract
  3. SubAccountContract
  4. AccountRecoveryContract
  5. AccountContract
  6. Initializable

Contracts (1-5) are Base Contracts, which in turn is a RentrancyGuard Smart Contract

```
contract BaseContract is ReentrancyGuardUpgradeable
```

In terms of Storage Layout, only BaseContract and ReentrancyGuardUpgradeable have storage variables. So our layout would look like the following:

1. Storage ReentrancyGuardUpgradeable
2. Storage BaseContract
3. [New Vars can be added here] in the base contract

#### Exampke of adding a new var in the base contract
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/1b21aec5-9ab7-41bd-b620-5253efb8c323)



### GRVTExchange contract

GRVTExchange has a global state declared in the [BaseContract](https://github.com/gravity-technologies/exchange-contract/blob/main/contracts/exchange/api/BaseContract.sol#L10) declared as a [State struct](https://github.com/gravity-technologies/exchange-contract/blob/main/contracts/exchange/types/DataStructure.sol#L76).

```
struct State {
  // A. Expanding State struct
  // B. Expanding mappings from Value/Address Type => Structs
  mapping(address => Account) accounts;
  mapping(uint64 => SubAccount) subAccounts;
  mapping(address => Session) sessions;

  // C. Expanding mappings from Enums => Structs
  mapping(ConfigID => bytes32) configs;
  mapping(ConfigID => ScheduledConfigEntry) scheduledConfig;
  mapping(ConfigID => ConfigTimelockRule[]) configTimelocks;

  // D. Expanding Structs
  ReplayState replay;
  PriceState prices;

  // E. Value Types
  int64 timestamp;
  uint64 lastTxID;
}
```

We have commented all the different fields in our global state. We will now dive into making the State variable upgradable and then each of the fields upgradable.

### A. Expanding the State Struct

According to Solidity [storage layout](https://docs.soliditylang.org/en/v0.8.13/internals/layout_in_storage.html), the elements of structs and arrays are stored after each other, just as if they were given as individual values." So if the struct is used as a state variable, then you should use gaps.

#### Experiment 1: Extending without using gaps 
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/1740751a-cc00-4e63-afd4-357e51985834)

#### Experiment 2: Extending a new field of value type with gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/05c03091-b67d-426d-8530-f1b97d091b73)

#### Experiment 3: Extending with a stuct field with gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/38db937f-2fb9-4893-afd5-42f00c174fc9)

#### Conclusion
Use [storage gaps](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#:~:text=Storage%20gaps%20are%20a%20convention,storage%20layout%20of%20child%20contracts.)- a convention for reserving storage slots in a base contract, allowing future versions of that contract to use up those slots without affecting the storage layout of child contracts.


### B. Expanding mappings from Value/Address Type => Structs

If the struct is stored in a mapping within the main State struct, there is no need for gaps within the struct that the value leads to (because they are not contiguous with other values). Mapping values are considered to occupy only 32 bytes and the elements they contain are stored starting at a different storage slot that is computed using a Keccak-256 hash because [mapping have unpredictable size and cannot be stored “in between” the state variables preceding and following them](https://docs.soliditylang.org/en/v0.8.13/internals/layout_in_storage.html#mappings-and-dynamic-arrays).

#### Experiment: Upgrading a contract by adding a field to a struct that is a value in one of the mappings
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/96aaf4f5-4e5a-4a7f-9c26-1a9cceaa73cb)

### C. Mappings from Enums => Structs

Mapping from Enums to struct follow the same logic. However, we have to be careful when expanding Enums. If the enum field lies within one and only one contract, it is [safe for an upgrade](https://hackernoon.com/beware-the-solidity-enums-9v1qa31b2). It is also [safe](https://hackernoon.com/beware-the-solidity-enums-9v1qa31b2) if you can ensure that all contracts using the enum are redeployed altogether in case of modification. Our contracts use enums, so they must take care of the above.

### D. Expanding Structs
As mentioned above, in Solidity's storage layout, the elements of structs are stored after each other. If the struct is used inside a state variable, then you should use gaps.

### Expreiment 1: Expanding Struct without storage gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/21519419-9bb8-4dba-a2bd-2096595d5353)

### Expreiment 2: Expanding Struct with storage gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/b705108c-c071-4d9f-af34-bf9dfb26fd7b)

### E. Value Types
Value types do not need to be expanded.
