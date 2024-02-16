// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/SubAccountSig.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../api/APIBase.t.sol";
import "../Base.t.sol";
import "../types/Types.sol";
import "./TradeBase.t.sol";

contract ManyLegOneMaker is TradeBase {
  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

  Asset internal assetOne;
  Asset internal assetTwo;
  Asset internal assetThree;
  OrderLeg[] internal legs;
  Order internal orderOne;
  Order internal orderTwo;
  Order internal orderThree;
  Trade internal trade;

  function setUp() public override {
    super.setUp();
    assetOne = createAsset(Kind.PERPS, Currency.USDT, 1, Currency.USDT, 2, 100, 100);
    assetTwo = createAsset(Kind.PERPS, Currency.USDT, 1, Currency.USDT, 2, 100, 100);
    assetThree = createAsset(Kind.PERPS, Currency.USDT, 1, Currency.USDT, 2, 100, 100);
    OrderLeg memory legOne = OrderLeg({
      assetID: 1,
      size: 100,
      limitPrice: 100,
      ocoLimitPrice: 100,
      isBuyingAsset: true
    });
    OrderLeg memory legTwo = OrderLeg({
      assetID: 2,
      size: 100,
      limitPrice: 100,
      ocoLimitPrice: 100,
      isBuyingAsset: true
    });
    OrderLeg memory legThree = OrderLeg({
      assetID: 3,
      size: 100,
      limitPrice: 100,
      ocoLimitPrice: 100,
      isBuyingAsset: true
    });

    legs.push(legOne);
    legs.push(legTwo);
    legs.push(legThree);
    orderOne = Order({
      subAccountID: 1,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      limitPrice: 100,
      ocoLimitPrice: 100,
      takerFeePercentageCap: 100,
      makerFeePercentageCap: 100,
      postOnly: false,
      reduceOnly: false,
      isPayingBaseCurrency: true,
      legs: legs,
      nonce: 1,
      signature: Signature(address(0), bytes32(0), bytes32(0), 0, 0, 0)
    });

    orderTwo = Order({
      subAccountID: 2,
      isMarket: false,
      timeInForce: TimeInForce.GOOD_TILL_TIME,
      limitPrice: 100,
      ocoLimitPrice: 100,
      takerFeePercentageCap: 100,
      makerFeePercentageCap: 100,
      postOnly: false,
      reduceOnly: false,
      isPayingBaseCurrency: true,
      legs: legs,
      nonce: 2,
      signature: Signature(address(0), bytes32(0), bytes32(0), 0, 0, 0)
    });

    uint64[] memory matchedSize = new uint64[](3);
    matchedSize[0] = 100;
    matchedSize[1] = 200;
    matchedSize[2] = 150;

    OrderMatch memory orderMatch = OrderMatch({
      makerOrder: orderTwo,
      matchedSize: matchedSize,
      takerFeePercentageCharged: 100,
      makerFeePercentageCharged: 100
    });
    OrderMatch[] memory orderMatches = new OrderMatch[](2);
    orderMatches[0] = orderMatch;

    AssetTradeContext[] memory assetTradeContexts = new AssetTradeContext[](1);
    AssetTradeContext memory assetTradeContext = AssetTradeContext({
      assetID: 1,
      markPrice: 100,
      underlyingPrice: 100,
      riskFreeRate: 100
    });

    assetTradeContexts[0] = assetTradeContext;

    trade = Trade({takerOrder: orderOne, makerOrders: orderMatches, tradeContext: assetTradeContexts});
  }

  function testMatchManyLegOneMaker() public {
    grvtExchange.tradeDeriv(0, 0, trade);
  }

  function createAsset(
    Kind _kind,
    Currency _underlying,
    uint256 _underlyingAssetID,
    Currency _quote,
    uint256 _quoteAssetID,
    uint32 _expiration,
    uint64 _strikePrice
  ) public pure returns (Asset memory) {
    Asset memory asset = Asset({
      kind: _kind,
      underlying: _underlying,
      underlyingAssetID: _underlyingAssetID,
      quote: _quote,
      quoteAssetID: _quoteAssetID,
      expiration: _expiration,
      strikePrice: _strikePrice
    });
    return asset;
  }
}
