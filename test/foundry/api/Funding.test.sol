// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../contracts/exchange/util/Asset.sol";
import "../../../contracts/exchange/api/FundingAndSettlement.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "forge-std/console.sol";

contract FundingTest is FundingAndSettlement, Test {
  function testPerpFunding() public {
    // Setup
    uint64 subID = 1;
    // Setup subaccount
    SubAccount storage sub = state.subAccounts[subID];
    sub.quoteCurrency = Currency.USDT;
    sub.lastAppliedFundingTimestamp = 0;

    // Create new perp position
    PositionsMap storage perps = sub.perps;
    Asset memory asset = Asset({
      kind: Kind.PERPS,
      underlying: Currency.ETH,
      quote: Currency.USDT,
      strikePrice: 0,
      expiration: 0
    });
    bytes32 assetID = assetToID(asset);
    Position storage perp = getOrNew(perps, assetID);
    perp.balance = int64(1 * int256(_decimalMultiplier(assetGetUnderlying(assetID))));
    perp.lastAppliedFundingIndex = _fundingIndex(0);
    state.prices.fundingIndex[assetID] = _fundingIndex(1);

    int64 newFundingTime = 1;
    state.prices.fundingTime = newFundingTime;

    // Apply funding
    _fundAndSettle(sub);

    // Asserts
    assertEq(sub.lastAppliedFundingTimestamp, newFundingTime, "Funding not applied");
    assertEq(perp.lastAppliedFundingIndex, _fundingIndex(1), "Funding not applied");
    assertEq(
      uint256(sub.spotBalances[Currency.USDT]),
      uint256(1 * _decimalMultiplier(sub.quoteCurrency)),
      "Funding not applied"
    );
  }

  function _decimalMultiplier(Currency currency) private pure returns (uint256) {
    return 10 ** _getCurrencyDecimal(currency);
  }

  function _fundingIndex(uint index) private pure returns (int64) {
    return int64(uint64(index * 10 ** uint64(PRICE_DECIMALS)));
  }
}
