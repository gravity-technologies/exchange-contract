// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// The type of each field in this struct have been extended from the one defined in https://github.com/gravity-technologies/smart-contract-interface/blob/main/state.go#L74C23-L74C23
// This is to allow better packing of the struct in storage
struct DerivativePosition {
  // The derivative contract held in this position
  uint256 id;
  // Number of contracts held in this position.
  int64 balance;
  // (expressed in USD with 10 decimal points)
  uint64 lastAppliedFundingIndex;
  // Timestamp when this position was created
  uint64 createdAt;
}

// Copied and modified from https://solidity-by-example.org/app/iterable-mapping/
struct DerivativeCollection {
  uint256[] keys;
  mapping(uint256 => DerivativePosition) values;
  mapping(uint256 => uint) index;
}

function set(DerivativeCollection storage map, uint256 key, DerivativePosition storage val) {
  if (map.values[key].id != 0) {
    map.values[key] = val;
    map.index[key] = map.keys.length;
    map.keys.push(key);
  } else map.values[key] = val;
}

function remove(DerivativeCollection storage map, uint256 key) {
  if (map.values[key].id == 0) return;

  delete map.values[key];

  uint256 index = map.index[key];
  uint256 lastKey = map.keys[map.keys.length - 1];

  map.index[lastKey] = index;
  delete map.index[key];

  map.keys[index] = lastKey;
  map.keys.pop();
}
