// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../util/Asset.sol";

function _verifyOrder(SubAccount storage sub, Order calldata o, bool isMakerOrder) view {
  if (o.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL || o.timeInForce == TimeInForce.FILL_OR_KILL) {
    require(!isMakerOrder && !o.postOnly, "IOC/FOK is taker+postonly");
  }

  if (o.postOnly) require(isMakerOrder, "invalid postOnly");

  if (o.reduceOnly) {
    uint legsLen = o.legs.length;
    for (uint i; i < legsLen; ++i) {
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
