// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

enum Instrument {
  UNSPECIFIED,
  PERPS,
  FUTURES,
  CALL,
  PUT
}

enum Currency {
  UNSPECIFIED,
  USDC,
  USDT,
  ETH,
  BTC
}

struct Derivative {
  Instrument instrument;
  Currency underlying;
  Currency quote;
  uint32 expiration;
  uint64 strikePrice;
}

struct DerivativePosition {
  // The derivative contract held in this position
  uint128 id;
  // Number of contracts held in this position
  uint128 contractBalance;
  // The average entry price of the contracts held in this position
  // Used for computing unrealized P&L
  // This value experiences rounding errors, so it is not guaranteed to be accurate, use as an indicator only
  // Important to track on StateMachine to serve unrealized P&L queries, but not important to track on the
  // smart contract. Smart contract doesn't rely on this field for any logic
  uint128 averageEntryPrice;
  // (expressed in USD with 10 decimal points)
  uint128 lastAppliedFundingIndex;
}

// Copied and modified from https://solidity-by-example.org/app/iterable-mapping/
struct DerivativeCollection {
  uint128[] keys;
  mapping(uint128 => DerivativePosition) values;
  mapping(uint128 => uint) index;
}

function get(DerivativeCollection storage map, uint128 key) view returns (DerivativePosition storage) {
  return map.values[key];
}

function getKeyAtIndex(DerivativeCollection storage map, uint index) view returns (uint128) {
  return map.keys[index];
}

function set(DerivativeCollection storage map, uint128 key, DerivativePosition storage val) {
  if (map.values[key].id == 0) {
    map.values[key] = val;
  } else {
    map.values[key] = val;
    map.index[key] = map.keys.length;
    map.keys.push(key);
  }
}

function remove(DerivativeCollection storage map, uint128 key) {
  if (map.values[key].id == 0) return;

  delete map.values[key];

  uint index = map.index[key];
  uint128 lastKey = map.keys[map.keys.length - 1];

  map.index[lastKey] = index;
  delete map.index[key];

  map.keys[index] = lastKey;
  map.keys.pop();
}
