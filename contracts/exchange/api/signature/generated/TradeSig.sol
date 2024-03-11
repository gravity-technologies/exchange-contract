// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORDER_H = keccak256(
  "Order(uint64 subAccountID,bool isMarket,uint8 timeInForce,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,OrderLeg[] legs,uint32 nonce)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

bytes32 constant _LEG_H = keccak256(
  "OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

function hashOrder(Order calldata o) pure returns (bytes32) {
  bytes memory legsEncoded;
  uint numLegs = o.legs.length;
  for (uint i; i < numLegs; ++i) legsEncoded = abi.encodePacked(legsEncoded, hashOrderLeg(o.legs[i]));

  return
    keccak256(
      abi.encode(
        _ORDER_H,
        o.subAccountID,
        o.isMarket,
        o.timeInForce,
        o.takerFeePercentageCap,
        o.makerFeePercentageCap,
        o.postOnly,
        o.reduceOnly,
        keccak256(legsEncoded),
        o.signature.nonce
      )
    );
}

/// @dev hash the order leg, but sort the limit price and ocoLimitPrice so that we can always use either 1 of the prices
function hashOrderLeg(OrderLeg calldata l) pure returns (bytes32) {
  if (l.limitPrice < l.ocoLimitPrice)
    return keccak256(abi.encode(_LEG_H, l.assetID, l.size, l.limitPrice, l.ocoLimitPrice, l.isBuyingAsset));
  return keccak256(abi.encode(_LEG_H, l.assetID, l.size, l.ocoLimitPrice, l.limitPrice, l.isBuyingAsset));
}
