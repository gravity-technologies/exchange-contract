// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import "../../contracts/exchange/api/RiskCheck.sol";
import "../../contracts/exchange/types/DataStructure.sol";
import {Position, PositionsMap, getOrNew} from "../../contracts/exchange/types/PositionMap.sol";

contract RiskCheckTest is Test, RiskCheck {
  RiskCheck public riskCheck;
  SubAccount internal subAccount;

  function setUp() public {
    riskCheck = new RiskCheck();
  }

  function test_IsReducingSize_PositivePosition() public {
    // Setup: Create a positive position of size 100
    bytes32 assetId = _getPerp(Currency.BTC);
    Position storage pos = getOrNew(subAccount.perps, assetId);
    pos.id = assetId;
    pos.balance = 100;
    pos.lastAppliedFundingIndex = 0;

    // Test case 1: Reducing position by selling 60 (should return true)
    OrderLeg[] memory legs = new OrderLeg[](1);
    legs[0] = OrderLeg({assetID: assetId, size: 60, limitPrice: 100, isBuyingAsset: false});

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertTrue(isReducing, "Should be reducing when selling part of positive position");
  }

  function test_IsReducingSize_NegativePosition() public {
    // Setup: Create a negative position of size -100
    bytes32 assetId = _getPerp(Currency.BTC);
    Position storage pos = getOrNew(subAccount.perps, assetId);
    pos.id = assetId;
    pos.balance = -100;
    pos.lastAppliedFundingIndex = 0;

    // Test case: Reducing position by buying 60 (should return true)
    OrderLeg[] memory legs = new OrderLeg[](1);
    legs[0] = OrderLeg({assetID: assetId, size: 60, limitPrice: 100, isBuyingAsset: true});

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertTrue(isReducing, "Should be reducing when buying to cover negative position");
  }

  function test_IsReducingSize_NotReducing() public {
    // Setup: Create a positive position of size 100
    bytes32 assetId = _getPerp(Currency.BTC);
    Position storage pos = getOrNew(subAccount.perps, assetId);
    pos.id = assetId;
    pos.balance = 100;
    pos.lastAppliedFundingIndex = 0;

    // Test case: Increasing position by buying 50 more (should return false)
    OrderLeg[] memory legs = new OrderLeg[](1);
    legs[0] = OrderLeg({assetID: assetId, size: 50, limitPrice: 100, isBuyingAsset: true});

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertFalse(isReducing, "Should not be reducing when increasing position");
  }

  function test_IsReducingSize_FullClose() public {
    // Setup: Create a positive position of size 100
    bytes32 assetId = _getPerp(Currency.BTC);
    Position storage pos = getOrNew(subAccount.perps, assetId);
    pos.id = assetId;
    pos.balance = 100;
    pos.lastAppliedFundingIndex = 0;

    // Test case: Fully closing position by selling 100 (should return true)
    OrderLeg[] memory legs = new OrderLeg[](1);
    legs[0] = OrderLeg({assetID: assetId, size: 100, limitPrice: 100, isBuyingAsset: false});

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertTrue(isReducing, "Should be reducing when fully closing position");
  }

  function test_IsReducingSize_MultipleLegs_AllReducing() public {
    // Setup: Create multiple positions
    bytes32 assetId1 = _getPerp(Currency.BTC);
    bytes32 assetId2 = _getPerp(Currency.ETH);
    bytes32 assetId3 = _getPerp(Currency.SOL);

    // Position 1: Long 100
    Position storage pos1 = getOrNew(subAccount.perps, assetId1);
    pos1.id = assetId1;
    pos1.balance = 100;
    pos1.lastAppliedFundingIndex = 0;

    // Position 2: Short -50
    Position storage pos2 = getOrNew(subAccount.perps, assetId2);
    pos2.id = assetId2;
    pos2.balance = -50;
    pos2.lastAppliedFundingIndex = 0;

    // Position 3: Long 75
    Position storage pos3 = getOrNew(subAccount.perps, assetId3);
    pos3.id = assetId3;
    pos3.balance = 75;
    pos3.lastAppliedFundingIndex = 0;

    // Create order with multiple legs, all reducing
    OrderLeg[] memory legs = new OrderLeg[](3);
    legs[0] = OrderLeg({assetID: assetId1, size: 50, limitPrice: 100, isBuyingAsset: false}); // Reduce long by selling
    legs[1] = OrderLeg({assetID: assetId2, size: 30, limitPrice: 100, isBuyingAsset: true}); // Reduce short by buying
    legs[2] = OrderLeg({assetID: assetId3, size: 25, limitPrice: 100, isBuyingAsset: false}); // Reduce long by selling

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertTrue(isReducing, "Should be reducing when all legs are reducing positions");
  }

  function test_IsReducingSize_MultipleLegs_OneNotReducing() public {
    // Setup: Create multiple positions
    bytes32 assetId1 = _getPerp(Currency.BTC);
    bytes32 assetId2 = _getPerp(Currency.ETH);
    bytes32 assetId3 = _getPerp(Currency.SOL);

    // Position 1: Long 100
    Position storage pos1 = getOrNew(subAccount.perps, assetId1);
    pos1.id = assetId1;
    pos1.balance = 100;

    // Position 2: Short -50
    Position storage pos2 = getOrNew(subAccount.perps, assetId2);
    pos2.id = assetId2;
    pos2.balance = -50;

    // Position 3: Long 75
    Position storage pos3 = getOrNew(subAccount.perps, assetId3);
    pos3.id = assetId3;
    pos3.balance = 75;

    // Create order with multiple legs, one not reducing
    OrderLeg[] memory legs = new OrderLeg[](3);
    legs[0] = OrderLeg({assetID: assetId1, size: 50, limitPrice: 100, isBuyingAsset: false}); // Reduce long by selling
    legs[1] = OrderLeg({assetID: assetId2, size: 30, limitPrice: 100, isBuyingAsset: true}); // Reduce short by buying
    legs[2] = OrderLeg({assetID: assetId3, size: 25, limitPrice: 100, isBuyingAsset: true}); // Increase long by buying (not reducing)

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertFalse(isReducing, "Should not be reducing when any leg increases position");
  }

  function test_IsReducingSize_MultipleLegs_MixedPositions() public {
    // Setup: Create multiple positions with mixed states
    bytes32 assetId1 = _getPerp(Currency.BTC);
    bytes32 assetId2 = _getPerp(Currency.ETH);
    bytes32 assetId3 = _getPerp(Currency.SOL);
    bytes32 assetId4 = _getPerp(Currency.BNB);

    // Position 1: Long 100
    Position storage pos1 = getOrNew(subAccount.perps, assetId1);
    pos1.id = assetId1;
    pos1.balance = 100;
    pos1.lastAppliedFundingIndex = 0;

    // Position 2: Short -50
    Position storage pos2 = getOrNew(subAccount.perps, assetId2);
    pos2.id = assetId2;
    pos2.balance = -50;
    pos2.lastAppliedFundingIndex = 0;

    // Position 3: No position (0)
    Position storage pos3 = getOrNew(subAccount.perps, assetId3);
    pos3.id = assetId3;
    pos3.balance = 0;
    pos3.lastAppliedFundingIndex = 0;

    // Position 4: Long 25
    Position storage pos4 = getOrNew(subAccount.perps, assetId4);
    pos4.id = assetId4;
    pos4.balance = 25;
    pos4.lastAppliedFundingIndex = 0;

    // Create order with multiple legs testing various scenarios
    OrderLeg[] memory legs = new OrderLeg[](4);
    legs[0] = OrderLeg({assetID: assetId1, size: 100, limitPrice: 100, isBuyingAsset: false}); // Full close long
    legs[1] = OrderLeg({assetID: assetId2, size: 50, limitPrice: 100, isBuyingAsset: true}); // Full close short
    legs[2] = OrderLeg({assetID: assetId3, size: 25, limitPrice: 100, isBuyingAsset: true}); // Open new long (not reducing)
    legs[3] = OrderLeg({assetID: assetId4, size: 25, limitPrice: 100, isBuyingAsset: false}); // Full close long

    Order memory order = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      postOnly: false,
      reduceOnly: false,
      legs: legs,
      signature: Signature({signer: address(0), r: bytes32(0), s: bytes32(0), v: 0, expiration: 0, nonce: 0}),
      isLiquidation: false
    });

    bool isReducing = this.orderReducesPosition(order);
    assertFalse(isReducing, "Should not be reducing when any leg opens new position");
  }

  // External helper to expose _isReducingSize for testing
  function orderReducesPosition(Order calldata order) external view returns (bool) {
    return _isReducingOrder(subAccount, order);
  }

  function _getPerp(Currency underlying) private returns (bytes32) {
    return
      assetToID(Asset({kind: Kind.PERPS, underlying: underlying, quote: Currency.USDT, expiration: 0, strikePrice: 0}));
  }
}
