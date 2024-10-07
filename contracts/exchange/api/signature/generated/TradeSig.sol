// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORDER_H = keccak256(
  "Order(uint64 subAccountID,bool isMarket,uint8 timeInForce,bool postOnly,bool reduceOnly,OrderLeg[] legs,uint32 nonce,int64 expiration)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,bool isBuyingContract)"
);

function hashOrder(Order calldata o) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _ORDER_H,
        o.subAccountID,
        o.isMarket,
        o.timeInForce,
        o.postOnly,
        o.reduceOnly,
        hashOrderLegs(o.legs),
        o.signature.nonce,
        o.signature.expiration
      )
    );
}

bytes32 constant _LEG_H = keccak256(
  "OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,bool isBuyingContract)"
);

/// @dev hash the order legs,
/// @param legs the order legs
/// @return the hash of the order legs
function hashOrderLegs(OrderLeg[] calldata legs) pure returns (bytes32) {
  uint numLegs = legs.length;
  bytes32[] memory hashedLegs = new bytes32[](numLegs);
  for (uint i; i < numLegs; ++i) {
    OrderLeg calldata leg = legs[i];
    hashedLegs[i] = keccak256(abi.encode(_LEG_H, leg.assetID, leg.size, leg.limitPrice, leg.isBuyingAsset));
  }
  return keccak256(abi.encodePacked(hashedLegs));
}
