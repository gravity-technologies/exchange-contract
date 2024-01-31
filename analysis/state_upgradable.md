## State Management for Upgradable Contracts

### Overview

GRVTExchange has a global state declared in the [BaseContract](https://github.com/gravity-technologies/exchange-contract/blob/main/contracts/exchange/api/BaseContract.sol#L10) declared as a [State struct](https://github.com/gravity-technologies/exchange-contract/blob/main/contracts/exchange/types/DataStructure.sol#L76).

```
struct State {
  // A. Mappings from Value/Address Type => Structs
  mapping(address => Account) accounts;
  mapping(uint64 => SubAccount) subAccounts;
  mapping(address => Session) sessions;

  // B. Mappings from Enums => Structs
  mapping(ConfigID => bytes32) configs;
  mapping(ConfigID => ScheduledConfigEntry) scheduledConfig;
  mapping(ConfigID => ConfigTimelockRule[]) configTimelocks;

  // C. Structs
  ReplayState replay;
  PriceState prices;

  // D. Value Types
  int64 timestamp;
  uint64 lastTxID;
}
```

We have commented all the different fields in our global state. We will now dive into making the State variable upgradable and then each of the fields upgradable.

### Expanding the State Struct

According to Solidity [storage layout](https://docs.soliditylang.org/en/v0.8.13/internals/layout_in_storage.html), the elements of structs and arrays are stored after each other, just as if they were given as individual values." So if the struct is used as a state variable, then you should use gaps.

#### Experiment 1: Extending without using gaps 
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/1740751a-cc00-4e63-afd4-357e51985834)

#### Experiment 2: Extending a new field of value type with gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/05c03091-b67d-426d-8530-f1b97d091b73)

#### Experiment 3: Extending with a stuct field with gaps
![image](https://github.com/gravity-technologies/exchange-contract/assets/40881096/38db937f-2fb9-4893-afd5-42f00c174fc9)

#### Conclusion
Use [storage gaps](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#:~:text=Storage%20gaps%20are%20a%20convention,storage%20layout%20of%20child%20contracts.)- a convention for reserving storage slots in a base contract, allowing future versions of that contract to use up those slots without affecting the storage layout of child contracts.
