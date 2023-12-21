// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../types/DataStructure.sol";

// keccak256("Order(address subAccountID,bool isMarket,uint8 timeInForce,uint64 limitPrice,uint64 ocoLimitPrice,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,bool isPayingBaseCurrency,OrderLeg[] legs,uint32 nonce)OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)");
bytes32 constant _ORDER_H = bytes32(0x07ffec62d266471031104189858e1420c7c9b5b9e997dd2cd93d28431c4c2aa5);

// keccak256("OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)");
bytes32 constant _LEG_H = bytes32(0x6a1114282cec490e531ba67ea409944dee9d423e4921909d25afc9f4af988add);

function hashOrder(Order calldata o) pure returns (bytes32) {
  bytes memory legsEncoded;
  for (uint i = 0; i < o.legs.length; i++) legsEncoded = abi.encodePacked(legsEncoded, hashOrderLeg(o.legs[i]));
  bytes memory encoded = abi.encode(
    _ORDER_H,
    o.subAccountID,
    o.isMarket,
    o.timeInForce,
    o.limitPrice,
    o.takerFeePercentageCap,
    o.makerFeePercentageCap,
    o.postOnly,
    o.reduceOnly,
    o.isPayingBaseCurrency,
    keccak256(legsEncoded),
    o.nonce
  );
  return keccak256(encoded);
}

/// @dev hash the order leg, but sort the limit price and ocoLimitPrice so that we can always use either 1 of the prices
function hashOrderLeg(OrderLeg calldata l) pure returns (bytes32) {
  if (l.limitPrice < l.ocoLimitPrice)
    return keccak256(abi.encode(_LEG_H, l.assetID, l.size, l.limitPrice, l.ocoLimitPrice, l.isBuyingAsset));
  return keccak256(abi.encode(_LEG_H, l.assetID, l.size, l.ocoLimitPrice, l.limitPrice, l.isBuyingAsset));
}
