// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./MarginConfigContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

struct MaintenanceMarginConfig {
  BI size;
  BI ratio;
}

// The maximum number of maintenance margin tiers
uint256 constant MAX_M_MARGIN_TIERS = 12;
// The bit mask for the least significant 32 bits
uint256 constant LSB_32_MASK = 0xFFFFFFFF;

// Only support BTC, ETH for now
uint constant NUM_SUPPORTED_UNDERLYINGS = 2;

contract RiskCheck is BaseContract, MarginConfigContract {
  using BIMath for BI;

  error InvalidTotalValue(uint64 subAccountID, int256 value);

  function _requireValidMargin(SubAccount storage sub, bool isLiquidation, bool beforeTrade) internal view {
    (uint64 liquidationSubID, bool liquidationSubConfigured) = _getUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);

    // Insurance Fund can Trade when under MM, and in Negative Equity
    if (liquidationSubConfigured && sub.id == liquidationSubID) {
      return;
    }

    if (isLiquidation && beforeTrade) {
      require(!isAboveMaintenanceMargin(sub), "subaccount liquidated is above maintenance margin");
    } else {
      _requireNonNegativeUsdValue(sub);
    }
  }

  function _requireNonNegativeUsdValue(SubAccount storage sub) internal view {
    require(_getSubAccountUsdValue(sub).val >= 0, "invalid total value");
  }

  /// @dev Get the total value of a sub account in quote currency decimal
  function _getSubAccountUsdValue(SubAccount storage sub) internal view returns (BI memory) {
    BI memory totalValue = _getPositionsUsdValue(sub.perps).add(_getPositionsUsdValue(sub.futures)).add(
      _getPositionsUsdValue(sub.options)
    );

    for (Currency i = currencyStart(); currencyIsValid(i); i = currencyNext(i)) {
      int64 balance = sub.spotBalances[i];
      if (balance == 0) {
        continue;
      }
      BI memory balanceBI = BI(int256(balance), _getBalanceDecimal(i));
      bytes32 spotID = _getSpotAssetID(i);
      totalValue = totalValue.add(balanceBI.mul(_requireMarkPriceBI(spotID)));
    }

    return totalValue;
  }

  /// @dev Get the total value of a position collections
  function _getPositionsUsdValue(PositionsMap storage positions) internal view returns (BI memory) {
    BI memory total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      bytes32 assetWithUSDQuote = assetSetQuote(pos.id, Currency.USD);
      BI memory markPrice = _requireMarkPriceBI(assetWithUSDQuote);
      uint64 uDec = _getBalanceDecimal(assetGetUnderlying(assetWithUSDQuote));
      BI memory balance = BI(int256(pos.balance), uDec);
      total = total.add(balance.mul(markPrice));
    }
    return total;
  }

  /**
   * @dev Check the current subaccount margin level. If the subaccount is below the maintenance margin,
   * it is liquidatable.
   * @param subAccount The subaccount to check.
   * @return True if the subaccount is below the maintenance margin, false otherwise.
   */
  function isAboveMaintenanceMargin(SubAccount storage subAccount) internal view returns (bool) {
    require(subAccount.marginType == MarginType.SIMPLE_CROSS_MARGIN, "invalid margin type");
    uint usdDecimals = _getBalanceDecimal(Currency.USD);

    int64 subAccountValue = _getSubAccountUsdValue(subAccount).toInt64(usdDecimals);
    uint64 maintenanceMargin = _getSubMaintenanceMargin(subAccount);

    return subAccountValue >= 0 && uint64(subAccountValue) >= maintenanceMargin;
  }

  /**
   * @dev Returns the maintenance margin for a subaccount.
   * @param subAccount The subaccount to check.
   * @return The maintenance margin.
   */
  function _getSubMaintenanceMargin(SubAccount storage subAccount) internal view returns (uint64) {
    BI memory totalCharge = BI(0, 0);

    bytes32[] storage keys = subAccount.perps.keys;
    mapping(bytes32 => Position) storage values = subAccount.perps.values;
    uint numPerps = keys.length;
    for (uint i = 0; i < numPerps; i++) {
      bytes32 id = keys[i];
      int64 size = values[id].balance;
      if (size < 0) {
        size = -size;
      }
      bytes32 kuq = assetGetKUQ(id);
      ListMarginTiersBI memory mt = state.simpleCrossMaintenanceMarginTiers[kuq];
      BI memory sizeBI = BI(int256(size), _getBalanceDecimal(assetGetUnderlying(id)));
      BI memory charge = _calculateSimpleCrossMMSize(mt, sizeBI).mul(_requireMarkPriceBI(id));
      totalCharge = totalCharge.add(charge);
    }

    return totalCharge.toUint64(_getBalanceDecimal(Currency.USD));
  }
}
