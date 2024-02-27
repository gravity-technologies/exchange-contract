// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// The type of each field in this struct have been extended from the one defined in https://github.com/gravity-technologies/smart-contract-interface/blob/main/state.go#L74C23-L74C23
// This is to allow better packing of the struct in storage
struct Position {
  // The derivative contract held in this position
  bytes32 id;
  // Number of contracts held in this position.
  int64 balance;
  // (expressed in USD with 10 decimal points)
  int64 lastAppliedFundingIndex;
}

// Copied and modified from https://solidity-by-example.org/app/iterable-mapping/
struct PositionsMap {
  bytes32[] keys;
  mapping(bytes32 => Position) values;
  mapping(bytes32 => uint) index;
  uint256[49] __gap;
}

function set(PositionsMap storage map, bytes32 key, Position storage pos) {
  if (map.values[key].id != 0) {
    map.values[key] = pos;
    map.index[key] = map.keys.length;
    map.keys.push(key);
  } else map.values[key] = pos;
}

function remove(PositionsMap storage map, bytes32 key) {
  if (map.values[key].id == 0) return;

  delete map.values[key];

  uint index = map.index[key];
  bytes32 lastKey = map.keys[map.keys.length - 1];

  map.index[lastKey] = index;
  delete map.index[key];

  map.keys[index] = lastKey;
  map.keys.pop();
}
