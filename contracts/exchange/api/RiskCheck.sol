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

  function _getSocializedLossHaircutAmount(int64 withdrawAmount) internal view returns (uint64) {
    int64 insuranceFundLossAmount = _getInsuranceFundLossAmount();
    if (insuranceFundLossAmount <= 0) {
      return 0;
    }

    uint dec = _getBalanceDecimal(Currency.USDT);

    int64 totalClientValue = _getTotalClientValueUSDT();
    BI memory totalClientValueBI = BI(totalClientValue, dec);
    BI memory insuranceFundLossAmountBI = BI(insuranceFundLossAmount, dec);

    // result = withdrawAmount * (insuranceFundLoss / totalClientValue)
    BI memory withdrawAmountBI = BI(withdrawAmount, dec);
    BI memory result = withdrawAmountBI.mul(insuranceFundLossAmountBI).div(totalClientValueBI);
    return result.toUint64(dec);
  }

  function _getTotalClientValueUSDT() internal view returns (int64) {
    return state.totalSpotBalances[Currency.USDT];
  }

  function _getTotalInternalValueUSDT() internal view returns (int64) {
    int64 totalValue = 0;

    uint dec = _getBalanceDecimal(Currency.USDT);

    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet) {
      totalValue += _getSubAccountValueInQuote(insuranceFund).toInt64(dec);
    }

    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();
    if (isFeeSubAccIdSet) {
      totalValue += _getSubAccountValueInQuote(feeSubAcc).toInt64(dec);
    }

    // include bridging partner balances?

    return totalValue;
  }

  function _getInsuranceFundLossAmount() internal view returns (int64) {
    uint dec = _getBalanceDecimal(Currency.USDT);

    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet) {
      int64 insuranceFundValue = _getSubAccountValueInQuote(insuranceFund).toInt64(dec);
      if (insuranceFundValue < 0) {
        return -insuranceFundValue;
      }
    }
    return 0;
  }

  function _requireValidMargin(SubAccount storage sub, bool isLiquidation, bool beforeTrade) internal view {
    (uint64 liquidationSubID, bool liquidationSubConfigured) = _getUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);

    // Insurance Fund can Trade when under MM, and in Negative Equity
    if (liquidationSubConfigured && sub.id == liquidationSubID) {
      return;
    }

    if (isLiquidation && beforeTrade) {
      require(!isAboveMaintenanceMargin(sub), "subaccount liquidated is above maintenance margin");
    } else if (isLiquidation && !beforeTrade) {
      _requireNonNegativeValue(sub);
    } else {
      require(isAboveMaintenanceMargin(sub), "subaccount is below maintenance margin");
    }
  }

  function _requireNonNegativeValue(SubAccount storage sub) internal view {
    require(_getSubAccountValueInQuote(sub).val >= 0, "invalid total value");
  }

  /// @dev Get the total value of a sub account in quote currency
  function _getSubAccountValueInQuote(SubAccount storage sub) internal view returns (BI memory) {
    BI memory totalValue = _getPositionsValueInQuote(sub.perps).add(_getPositionsValueInQuote(sub.futures)).add(
      _getPositionsValueInQuote(sub.options)
    );

    for (Currency i = currencyStart(); currencyIsValid(i); i = currencyNext(i)) {
      int64 balance = sub.spotBalances[i];
      if (balance == 0) {
        continue;
      }
      BI memory balanceBI = BI(balance, _getBalanceDecimal(i));
      BI memory spotPriceInQuote = _getSpotPriceInQuote(i, sub.quoteCurrency);
      totalValue = totalValue.add(balanceBI.mul(spotPriceInQuote));
    }

    return totalValue;
  }

  /// @dev Get the total value of a position collections in quote currency
  function _getPositionsValueInQuote(PositionsMap storage positions) internal view returns (BI memory) {
    BI memory total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      bytes32 assetID = pos.id;
      Currency underlying = assetGetUnderlying(assetID);
      uint64 uDec = _getBalanceDecimal(underlying);
      BI memory balance = BI(pos.balance, uDec);
      BI memory assetPrice = _requireAssetPriceBI(assetID);
      total = total.add(balance.mul(assetPrice));
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

    int64 subAccountValue = _getSubAccountValueInQuote(subAccount).toInt64(usdDecimals);
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
      BI memory sizeBI = BI(size, _getBalanceDecimal(assetGetUnderlying(id)));
      BI memory charge = _calculateSimpleCrossMMSize(mt, sizeBI).mul(_requireAssetPriceInUsdBI(id));
      totalCharge = totalCharge.add(charge);
    }

    BI memory quotePrice = _getSpotPriceBI(subAccount.quoteCurrency);
    uint64 qDec = _getBalanceDecimal(Currency.USD);

    return totalCharge.div(quotePrice).toUint64(qDec);
  }
}
