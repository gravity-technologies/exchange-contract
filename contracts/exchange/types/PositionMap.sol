// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct Position {
  bytes32 id;
  int64 balance;
  int64 lastAppliedFundingIndex;
}

struct PositionsMap {
  bytes32[] keys;
  mapping(bytes32 => Position) values;
  mapping(bytes32 => uint) index;
  uint256[49] __gap;
}

function getOrNew(PositionsMap storage map, bytes32 assetID) returns (Position storage) {
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
