// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORDER_H = keccak256(
  "Order(uint64 subAccountID,bool isMarket,uint8 timeInForce,bool postOnly,bool reduceOnly,OrderLeg[] legs,uint32 nonce,int64 expiration)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,bool isBuyingContract)"
);
bytes32 constant _ORDER_WITH_BUILDER_FEE_H = keccak256(
  "OrderWithBuilderFee(uint64 subAccountID,bool isMarket,uint8 timeInForce,bool postOnly,bool reduceOnly,OrderLeg[] legs,address builder,uint32 builderFee,uint32 nonce,int64 expiration)OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,bool isBuyingContract)"
);

/// @dev Hashes the EIP-712 order payload used during trade signature validation.
/// Use this on full orders after upstream validation has enforced that at least one leg is present.
function hashOrder(Order calldata o) pure returns (bytes32 result) {
  bytes32 legsHash;
  if (o.legs.length == 1) {
    bytes32 legHash = hashOrderLeg(o.legs[0]);
    assembly ("memory-safe") {
      let p := mload(0x40)
      mstore(p, legHash)
      legsHash := keccak256(p, 0x20)
    }
  } else {
    legsHash = hashOrderLegs(o.legs);
  }

  uint64 subAccountID = o.subAccountID;
  bool isMarket = o.isMarket;
  uint8 timeInForce = uint8(o.timeInForce);
  bool postOnly = o.postOnly;
  bool reduceOnly = o.reduceOnly;
  uint32 nonce = o.signature.nonce;
  int64 expiration = o.signature.expiration;

  if (o.builder == address(0) && o.builderFee == 0) {
    bytes32 orderTypeHash = _ORDER_H;
    assembly ("memory-safe") {
      let p := mload(0x40)
      mstore(p, orderTypeHash)
      mstore(add(p, 0x20), and(subAccountID, 0xffffffffffffffff))
      mstore(add(p, 0x40), iszero(iszero(isMarket)))
      mstore(add(p, 0x60), and(timeInForce, 0xff))
      mstore(add(p, 0x80), iszero(iszero(postOnly)))
      mstore(add(p, 0xA0), iszero(iszero(reduceOnly)))
      mstore(add(p, 0xC0), legsHash)
      mstore(add(p, 0xE0), and(nonce, 0xffffffff))
      mstore(add(p, 0x100), signextend(7, expiration))
      result := keccak256(p, 0x120)
    }
    return result;
  }

  address builder = o.builder;
  uint32 builderFee = o.builderFee;
  bytes32 orderWithBuilderTypeHash = _ORDER_WITH_BUILDER_FEE_H;

  assembly ("memory-safe") {
    let p := mload(0x40)
    mstore(p, orderWithBuilderTypeHash)
    mstore(add(p, 0x20), and(subAccountID, 0xffffffffffffffff))
    mstore(add(p, 0x40), iszero(iszero(isMarket)))
    mstore(add(p, 0x60), and(timeInForce, 0xff))
    mstore(add(p, 0x80), iszero(iszero(postOnly)))
    mstore(add(p, 0xA0), iszero(iszero(reduceOnly)))
    mstore(add(p, 0xC0), legsHash)
    mstore(add(p, 0xE0), and(builder, 0xffffffffffffffffffffffffffffffffffffffff))
    mstore(add(p, 0x100), and(builderFee, 0xffffffff))
    mstore(add(p, 0x120), and(nonce, 0xffffffff))
    mstore(add(p, 0x140), signextend(7, expiration))
    result := keccak256(p, 0x160)
  }
}

bytes32 constant _LEG_H = keccak256(
  "OrderLeg(uint256 assetID,uint64 contractSize,uint64 limitPrice,bool isBuyingContract)"
);

/// @dev Hashes a single order leg into the fixed-width EIP-712 struct hash.
/// Use this for the single-leg fast path or when building the packed leg hash for a parent order.
function hashOrderLeg(OrderLeg calldata leg) pure returns (bytes32 result) {
  bytes32 legTypeHash = _LEG_H;
  bytes32 assetID = leg.assetID;
  uint64 size = leg.size;
  uint64 limitPrice = leg.limitPrice;
  bool isBuyingAsset = leg.isBuyingAsset;

  assembly ("memory-safe") {
    let p := mload(0x40)
    mstore(p, legTypeHash)
    mstore(add(p, 0x20), assetID)
    mstore(add(p, 0x40), and(size, 0xffffffffffffffff))
    mstore(add(p, 0x60), and(limitPrice, 0xffffffffffffffff))
    mstore(add(p, 0x80), iszero(iszero(isBuyingAsset)))
    result := keccak256(p, 0xA0)
  }
}

/// @dev Hashes the packed sequence of per-leg EIP-712 struct hashes.
/// Use this only for orders with more than one leg; single-leg orders should use `hashOrderLeg` directly.
/// @param legs the order legs
/// @return result the hash of the order legs
function hashOrderLegs(OrderLeg[] calldata legs) pure returns (bytes32 result) {
  uint256 numLegs = legs.length;
  uint256 hashesPtr;
  assembly ("memory-safe") {
    hashesPtr := mload(0x40)
    mstore(0x40, add(hashesPtr, shl(5, numLegs)))
  }

  for (uint256 i; i < numLegs; ) {
    bytes32 legHash = hashOrderLeg(legs[i]);
    assembly ("memory-safe") {
      mstore(add(hashesPtr, shl(5, i)), legHash)
    }
    unchecked {
      ++i;
    }
  }

  assembly ("memory-safe") {
    result := keccak256(hashesPtr, shl(5, numLegs))
  }
}

bytes32 constant _HASH_ADD_ISOLATED_POSITION_MARGIN_H = keccak256(
  "AddIsolatedPositionMargin(uint64 subAccountID,uint256 asset,int64 amount,uint32 nonce,int64 expiration)"
);

/// @dev Hashes the isolated margin update payload for signature validation.
function hashAddIsolatedPositionMargin(
  uint64 subAccountID,
  bytes32 assetID,
  int64 amount,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_HASH_ADD_ISOLATED_POSITION_MARGIN_H, subAccountID, assetID, amount, nonce, expiration));
}
