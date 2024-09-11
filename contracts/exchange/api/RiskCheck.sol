// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./ConfigContract.sol";
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
// The bit mask for the least significant 24 bits, used for Kind, Underlying, Quote encoding in determining the insurance fund subaccount ID
bytes32 constant KUQ_MASK = bytes32(uint256(0xFFFFFF));

contract RiskCheck is BaseContract, ConfigContract {
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
   * @dev Returns the maintenance margin config for all currency
   * @return The maintenance margin config for all currency, indexed by (currency_enum_value - ETH_enum_value)
   */
  function _getAllMaintenanceMarginConfig()
    private
    view
    returns (MaintenanceMarginConfig[MAX_M_MARGIN_TIERS][] memory)
  {
    uint numCurrencies = uint(Currency.BTC) - uint(Currency.ETH) + 1;

    MaintenanceMarginConfig[MAX_M_MARGIN_TIERS][] memory configs = new MaintenanceMarginConfig[MAX_M_MARGIN_TIERS][](
      numCurrencies
    );

    // Add the maintenance margin config for each currency
    for (uint i = 0; i < numCurrencies; i++) {
      configs[i] = _getMaintenanceMarginConfigByCurrency(Currency(i + uint(Currency.ETH)));
    }
    return configs;
  }

  /**
   * @dev Returns the maintenance margin config for a given currency
   * Each maintenance margin tier config value is stored as a bytes32 value
   * The encoding of that value is as follows, where size and ratio are fixed point numbers with 4 decimals:
   * +-------------------------------+
   * |    Size    |       Ratio      |
   * |  (32 bits) |      (32 bits)   |
   * +--------------------------------+
   *
   * @param currency The currency to get the maintenance margin config for
   * @return The maintenance margin config for the currency
   */
  function _getMaintenanceMarginConfigByCurrency(
    Currency currency
  ) private view returns (MaintenanceMarginConfig[MAX_M_MARGIN_TIERS] memory) {
    bytes32 currencyConfig = _currencyToConfig(currency);
    MaintenanceMarginConfig[MAX_M_MARGIN_TIERS] memory configs;
    uint hi = uint(ConfigID.SIMPLE_CROSS_MAINTENANCE_MARGIN_TIER_12);
    uint lo = uint(ConfigID.SIMPLE_CROSS_MAINTENANCE_MARGIN_TIER_01);
    for (uint i = lo; i <= hi; i++) {
      (bytes32 mmBytes32, bool found) = _getByte32Config2D(ConfigID(i), currencyConfig);
      if (!found) {
        break;
      }
      uint256 mm = uint256(mmBytes32);
      configs[i - lo].size = BI(int256(uint256((mm >> 224) & LSB_32_MASK)), 4);
      configs[i - lo].ratio = BI(int256(uint256((mm >> 160) & LSB_32_MASK)), 4);
    }
    return configs;
  }

  /**
   * @dev Check the current subaccount margin level. If the subaccount is below the maintenance margin,
   * it is liquidatable.
   * @param subAccount The subaccount to check.
   * @return True if the subaccount is below the maintenance margin, false otherwise.
   */
  function isAboveMaintenanceMargin(SubAccount storage subAccount) internal view returns (bool) {
    uint usdDecimals = _getBalanceDecimal(Currency.USD);

    int64 subAccountValue = _getSubAccountUsdValue(subAccount).toInt64(usdDecimals);
    uint64 maintenanceMargin = _getSubMaintenanceMargin(subAccount);

    return subAccountValue >= 0 && uint64(subAccountValue) >= maintenanceMargin;
  }

  /**
   * @dev Find the maintenance margin ratio for a given position size. The maintenance margin ratio is a sorted array according to the position size.
   * To find the maintenance margin ratio, we iterate through the maintenance margin tiers and find the first tier where the size is greater than or equal to the tier size.
   * @param size The position size.
   * @param configs The maintenance margin configurations.
   * @return The maintenance margin ratio, in BI format.
   */
  function _getMaintenanceMarginRatio(
    BI memory size,
    MaintenanceMarginConfig[MAX_M_MARGIN_TIERS] memory configs
  ) internal pure returns (BI memory) {
    uint idx = configs.length - 1;

    for (uint i = 0; i < configs.length; i++) {
      if (size.cmp(configs[i].size) < 0) {
        idx = i;
        break;
      }
    }
    return configs[idx].ratio;
  }

  /**
   * @dev Returns the maintenance margin for a subaccount.
   * @param subAccount The subaccount to check.
   * @return The maintenance margin.
   */
  function _getSubMaintenanceMargin(SubAccount storage subAccount) internal view returns (uint64) {
    BI memory totalCharge = BI(0, 0);

    // Load the maintenance margin config for each currency up front to save cost from repeated lookups
    MaintenanceMarginConfig[MAX_M_MARGIN_TIERS][] memory mmConfigs = _getAllMaintenanceMarginConfig();

    bytes32[] storage keys = subAccount.perps.keys;
    mapping(bytes32 => Position) storage values = subAccount.perps.values;
    uint numPerps = keys.length;
    for (uint i = 0; i < numPerps; i++) {
      bytes32 id = keys[i];
      Currency underlyingCurrency = assetGetUnderlying(id);
      int64 size = values[id].balance;
      if (size < 0) {
        size = -size;
      }
      BI memory sizeBI = BI(int256(size), _getBalanceDecimal(underlyingCurrency));
      uint mmConfigIdx = uint(underlyingCurrency) - uint(Currency.ETH);
      BI memory ratio = _getMaintenanceMarginRatio(sizeBI, mmConfigs[mmConfigIdx]);
      // The charge for a perpetual positions = (Size) * (Mark Price) * (Maintenance Ratio)
      BI memory charge = ratio.mul(_requireMarkPriceBI(id)).mul(sizeBI);
      totalCharge = totalCharge.add(charge);
    }

    return totalCharge.toUint64(_getBalanceDecimal(Currency.USD));
  }
}
