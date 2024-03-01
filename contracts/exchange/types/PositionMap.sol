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

function getOrNew(PositionsMap storage map, bytes32 assetID) returns (Position storage) {
  // If the position does not exists, set the id to the assetID to mark it's existence
  if (map.values[assetID].id == 0) {
    map.values[assetID].id = assetID;
    map.index[assetID] = map.keys.length;
    map.keys.push(assetID);
  }
  return map.values[assetID];
}

function remove(PositionsMap storage map, bytes32 assetID) {
  if (map.values[assetID].id == 0) return;

  delete map.values[assetID];

  uint index = map.index[assetID];
  bytes32 lastKey = map.keys[map.keys.length - 1];

  map.index[lastKey] = index;
  delete map.index[assetID];

  map.keys[index] = lastKey;
  map.keys.pop();
}
