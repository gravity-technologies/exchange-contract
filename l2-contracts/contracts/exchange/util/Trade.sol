// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../util/Asset.sol";

/**
 * @dev For the full list of validation, see https://docs.google.com/document/d/1S8qe5ulFvbn1ujmHTIYBO9uIJvpEai36bBw2lSqybak/edit
 * Note that these are the validation that trade data has to perform and not all of them are applicable to smart contract
 */
function _verifyOrder(SubAccount storage sub, Order calldata o, bool isMakerOrder) view {
  // Validate postOnly
  if (o.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL || o.timeInForce == TimeInForce.FILL_OR_KILL) {
    require(!isMakerOrder && !o.postOnly, "IOC/FOK is taker+postonly");
  }

  // Validate postOnly during trade
  if (o.postOnly) require(isMakerOrder, "invalid postOnly");

  // Validate reduceOnly during trade
  if (o.reduceOnly) {
    uint legsLen = o.legs.length;
    for (uint i; i < legsLen; ++i) {
      // if long -> selling
      // if shorts -> buying
      OrderLeg calldata leg = o.legs[i];
      int64 balance = getPosition(sub, leg.assetID).balance;
      require(
        balance == 0 || (balance > 0 && !leg.isBuyingAsset) || (balance < 0 && leg.isBuyingAsset),
        "invalid reduceOnly"
      );
    }
  }
}

function getPosition(SubAccount storage sub, bytes32 assetID) view returns (Position storage) {
  Kind kind = assetGetKind(assetID);
  require(kind != Kind.UNSPECIFIED, "invalid assetID");
  if (kind == Kind.PERPS) return sub.perps.values[assetID];
  if (kind == Kind.FUTURES) return sub.futures.values[assetID];
  return sub.options.values[assetID];
}
