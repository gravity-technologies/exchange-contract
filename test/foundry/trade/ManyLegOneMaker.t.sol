// SPDX-License-Identifier: UNLICENSED
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

  function setUp() public override {
    super.setUp();
    assetOne = createAsset(Kind.PERPS, Currency.USDT, Currency.USDT, 100, 100);
    assetTwo = createAsset(Kind.PERPS, Currency.USDT, Currency.USDT, 100, 100);
    assetThree = createAsset(Kind.PERPS, Currency.USDT, Currency.USDT, 100, 100);
  }

  function testMatchManyLegOneMaker() public pure {
    assert(true);
  }

  function createAsset(
    Kind _kind,
    Currency _underlying,
    Currency _quote,
    int64 _expiration,
    uint64 _strikePrice
  ) public pure returns (Asset memory) {
    Asset memory asset = Asset({
      kind: _kind,
      underlying: _underlying,
      quote: _quote,
      expiration: _expiration,
      strikePrice: _strikePrice
    });
    return asset;
  }
}
