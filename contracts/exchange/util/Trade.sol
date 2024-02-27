// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

uint constant _MAX_NUM_LEGS = 10;

/**
 * @dev For the full list of validation, see https://docs.google.com/document/d/1S8qe5ulFvbn1ujmHTIYBO9uIJvpEai36bBw2lSqybak/edit
 * Note that these are the validation that trade data has to perform and not all of them are applicable to smart contract
 */
function _verifyOrder(SubAccount storage sub, Order calldata o, bool isMakerOrder) view {
  // Validate limitPrice
  if (o.isMarket) {
    require(o.limitPrice == 0 && o.ocoLimitPrice == 0, "limit or oco price != 0");
  } else {
    require(o.limitPrice != 0 && o.ocoLimitPrice != 0, "missing limit or oco price");
  }
  // Validate postOnly
  if (o.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL || o.timeInForce == TimeInForce.FILL_OR_KILL) {
    require(isMakerOrder, "IOC or FOK are taker only");
    require(!o.postOnly, "IOC or FOK must be postOnly");
  }

  // Validate postOnly during trade
  if (o.postOnly) require(isMakerOrder, "invalid postOnly");

  // Validate reduceOnly during trade
  if (o.reduceOnly) {
    for (uint i; i < o.legs.length; ++i) {
      // if long -> selling
      // if shorts -> buying
      OrderLeg calldata leg = o.legs[i];
      Position storage pos = getPosition(sub, leg.assetID);
      require(
        pos.balance == 0 || (pos.balance > 0 && !leg.isBuyingAsset) || (pos.balance < 0 && leg.isBuyingAsset),
        "invalid reduceOnly"
      );
    }
  }

  // Validate legs are sorted by derivative ID
  OrderLeg[] calldata legs = o.legs;
  for (uint i = 1; i < legs.length; ++i) {
    require(legs[i - 1].assetID < legs[i].assetID, "legs not sorted");
  }
}

function getPosition(SubAccount storage sub, bytes32 assetID) view returns (Position storage) {
  Kind instrument = Kind(uint256(assetID) & 0xFF);
  require(instrument != Kind.UNSPECIFIED, "invalid assetID");
  if (instrument == Kind.CALL || instrument == Kind.PUT) return sub.options.values[assetID];
  if (instrument == Kind.PERPS) return sub.perps.values[assetID];
  return sub.futures.values[assetID];
}
