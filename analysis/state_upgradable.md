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
