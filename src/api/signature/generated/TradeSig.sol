// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../DataStructure.sol";

bytes32 constant _TRADE_PAYLOAD_H = keccak256(
  "TradePayload(Trade trade,uint32 nonce)Order(uint32 subAccountID,bool isMarket,uint8 timeInForce,uint64 limitPrice,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,bool isPayingBaseCurrency,OrderLeg[] legs,Signature signature)OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)OrderMatch(Order makerOrder,uint64[] numContractsMatched,uint32 takerFeePercentageCharged,uint32 makerFeePercentageCharged)Signature(address signer,uint256 r,uint256 s,uint8 v,int64 expiration)Trade(Order takerOrder,OrderMatch[] makerOrders)"
);

bytes32 constant _TRADE_H = keccak256(
  "Trade(Order takerOrder,OrderMatch[] makerOrders)Order(uint32 subAccountID,bool isMarket,uint8 timeInForce,uint64 limitPrice,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,bool isPayingBaseCurrency,OrderLeg[] legs,Signature signature)OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)OrderMatch(Order makerOrder,uint64[] numContractsMatched,uint32 takerFeePercentageCharged,uint32 makerFeePercentageCharged)Signature(address signer,uint256 r,uint256 s,uint8 v,int64 expiration)"
);

bytes32 constant _ORDER_H = keccak256(
  "Order(uint32 subAccountID,bool isMarket,uint8 timeInForce,uint64 limitPrice,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,bool isPayingBaseCurrency,OrderLeg[] legs,Signature signature)OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)Signature(address signer,uint256 r,uint256 s,uint8 v,int64 expiration)"
);

bytes32 constant _ORDER_LEG_H = keccak256(
  "OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)"
);

bytes32 constant _ORDER_MATCH_H = keccak256(
  "OrderMatch(Order makerOrder,uint64[] numContractsMatched,uint32 takerFeePercentageCharged,uint32 makerFeePercentageCharged)Order(uint32 subAccountID,bool isMarket,uint8 timeInForce,uint64 limitPrice,uint32 takerFeePercentageCap,uint32 makerFeePercentageCap,bool postOnly,bool reduceOnly,bool isPayingBaseCurrency,OrderLeg[] legs,Signature signature)OrderLeg(uint128 derivative,uint64 contractSize,uint64 limitPrice,uint64 ocoLimitPrice,bool isBuyingContract)Signature(address signer,uint256 r,uint256 s,uint8 v,int64 expiration)"
);

bytes32 constant _SIGNATURE_H = keccak256("Signature(address signer,uint256 r,uint256 s,uint8 v,int64 expiration)");

function hashTradePayload(TradePayload memory t) pure returns (bytes32) {
  return keccak256(abi.encode(_TRADE_PAYLOAD_H, hashTrade(t.trade), t.nonce));
}

function hashTrade(Trade memory t) pure returns (bytes32) {
  return keccak256(abi.encode(_TRADE_H, hashOrder(t.takerOrder), hashOrderMatchArray(t.makerOrders)));
}

function hashOrderMatchArray(OrderMatch[] memory o) pure returns (bytes32) {
  bytes memory encoded;
  for (uint i = 0; i < o.length; i++) {
    encoded = abi.encodePacked(encoded, hashOrderMatch(o[i]));
  }
  return keccak256(encoded);
}

function hashOrder(Order memory o) pure returns (bytes32) {
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
    hashOrderLegArray(o.legs),
    hashSignature(o.signature)
  );
  return keccak256(encoded);
}

function hashOrderLegArray(OrderLeg[] memory _input) pure returns (bytes32) {
  bytes memory encoded;
  for (uint i = 0; i < _input.length; i++) {
    encoded = abi.encodePacked(encoded, hashOrderLeg(_input[i]));
  }
  return keccak256(encoded);
}

function hashOrderLeg(OrderLeg memory l) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(_ORDER_LEG_H, l.derivative, l.contractSize, l.limitPrice, l.ocoLimitPrice, l.isBuyingContract)
    );
}

function hashOrderMatch(OrderMatch memory o) pure returns (bytes32) {
  bytes memory encoded = abi.encode(
    _ORDER_MATCH_H,
    hashOrder(o.makerOrder),
    hashUint64Array(o.numContractsMatched),
    o.takerFeePercentageCharged,
    o.makerFeePercentageCharged
  );
  return keccak256(encoded);
}

function hashUint64Array(uint64[] memory _input) pure returns (bytes32) {
  return keccak256(abi.encodePacked(_input));
}

function hashSignature(Signature memory s) pure returns (bytes32) {
  return keccak256(abi.encode(_SIGNATURE_H, s.signer, s.r, s.s, s.v, s.expiration));
}
