// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORDER_H = keccak256(
  "Order(uint64 subAccountID,bool isMarket,uint8 timeInForce,int32 takerFeePercentageCap,int32 makerFeePercentageCap,bool postOnly,bool reduceOnly,OrderLeg[] legs,uint32 nonce,int64 expiration)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

function hashOrder(Order calldata o) pure returns (bytes32) {
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
        hashOrderLegs(o.legs),
        o.signature.nonce,
        o.signature.expiration
      )
    );
}

bytes32 constant _LEG_H = keccak256(
  "OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

/// @dev hash the order legs,
/// @param legs the order legs
/// @return the hash of the order legs
function hashOrderLegs(OrderLeg[] calldata legs) pure returns (bytes32) {
  bytes memory legsEncoded;
  uint numLegs = legs.length;
  for (uint i; i < numLegs; ++i) {
    OrderLeg calldata leg = legs[i];
    bytes32 legHash;
    //sort the limit price and ocoLimitPrice so that we can always use either 1 of the prices
    if (leg.limitPrice < leg.ocoLimitPrice) {
      legHash = keccak256(
        abi.encode(_LEG_H, leg.assetID, leg.size, leg.limitPrice, leg.ocoLimitPrice, leg.isBuyingAsset)
      );
    } else {
      legHash = keccak256(
        abi.encode(_LEG_H, leg.assetID, leg.size, leg.ocoLimitPrice, leg.limitPrice, leg.isBuyingAsset)
      );
    }
    legsEncoded = abi.encodePacked(legsEncoded, legHash);
  }
  return keccak256(legsEncoded);
}

bytes32 constant _LIQUIDATION_ORDER_H = keccak256(
  "LiquidationOrder(uint64 subAccountID,OrderLeg[] legs,uint32 nonce,int64 expiration)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

function hashLiquidationOrder(LiquidationOrder calldata o) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(_LIQUIDATION_ORDER_H, o.subAccountID, hashOrderLegs(o.legs), o.signature.nonce, o.signature.expiration)
    );
}
