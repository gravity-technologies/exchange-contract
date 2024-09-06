// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./signature/generated/TradeSig.sol";
import "./RiskCheck.sol";
import "./ConfigContract.sol";
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

/**
 * @title LiquidationContract
 * @dev This contract handles the liquidation process for subaccounts.
 * It allows for both standard liquidations and auto-deleveraging, pdating positions, spot balances,
 * and handling fees accordingly. It ensures that subaccounts meet maintenance margin requirements
 * and integrates with insurance funds and backstop liquidity providers. Only perpetuals are
 * supported for liquidations.
 * Futures and options liquidations are not supported yet. They will be added in the future and
 * will require a contract upgrade
 */
contract LiquidationContract is ConfigContract, FundingAndSettlement, RiskCheck {
  using BIMath for BI;

  /**
   * @dev Executes multiple liquidation orders.
   *
   * @param timestamp The timestamp of the transaction.
   * @param txID The ID of the transaction.
   * @param lqd The liquidation event details.
   */
  function liquidate(int64 timestamp, uint64 txID, Liquidate calldata lqd) external {
    _setSequence(timestamp, txID);

    LiquidationOrder[] calldata orders = lqd.orders;
    for (uint i = 0; i < orders.length; i++) {
      liquidateOneOrder(orders[i], lqd.liquidatedSubAccountID, lqd.liquidationType);
    }
  }

  /**
   * @dev Executes a liquidation order.
   * This function handles the core logic for processing a liquidation order.
   * It updates positions and spot balances based on the order details.
   *
   * @param order The liquidation order details.
   * @param passiveSubAccountID The ID of the passive subaccount.
   * @param liquidationType The type of liquidation.
   */
  function liquidateOneOrder(
    LiquidationOrder calldata order,
    uint64 passiveSubAccountID,
    LiquidationType liquidationType
  ) private {
    SubAccount storage initiator = _requireSubAccount(order.subAccountID);
    SubAccount storage passive = _requireSubAccount(passiveSubAccountID);

    _fundAndSettle(initiator);
    _fundAndSettle(passive);

    // Validate the liquidation order based on its type
    if (liquidationType == LiquidationType.LIQUIDATE) {
      require(!isAboveMaintenanceMargin(passive), "Margin is above maintenance level");
    } else if (liquidationType == LiquidationType.AUTO_DELEVERAGE) {
      require(isAboveMaintenanceMargin(passive), "Margin is below maintenance level");
      require(order.liquidationFees == 0, "ADL takes no fee");
    }

    // Validate: The initiator must have the permission to trade
    _requireSubAccountPermission(initiator, order.signature.signer, SubAccountPermTrade);
    // Validate the initiator's signature must be valid
    _preventReplay(hashLiquidationOrder(order), order.signature);

    // Update positions and spot balances based on whether the initiator is buying or selling the asset
    for (uint i; i < order.legs.length; i++) {
      OrderLeg calldata leg = order.legs[i];
      Position storage initiatorPos = _getOrCreatePosition(initiator, leg.assetID);
      Position storage passivePos = _getOrCreatePosition(passive, leg.assetID);

      int64 sizeDelta = leg.isBuyingAsset ? -int64(leg.size) : int64(leg.size);
      _requireReduceOnly(passivePos.balance, sizeDelta);

      Currency quoteCurrency = assetGetQuote(leg.assetID);
      BI memory size = BI(int256(uint256(leg.size)), _getBalanceDecimal(assetGetUnderlying(leg.assetID)));
      BI memory limitPrice = BI(int256(uint256(leg.limitPrice)), PRICE_DECIMALS);
      int64 notionalValue = size.mul(limitPrice).toInt64(_getBalanceDecimal(quoteCurrency));
      if (leg.isBuyingAsset) {
        initiatorPos.balance += int64(leg.size);
        passivePos.balance -= int64(leg.size);
        initiator.spotBalances[quoteCurrency] -= notionalValue;
        passive.spotBalances[quoteCurrency] += notionalValue - int64(order.liquidationFees);
      } else {
        initiatorPos.balance -= int64(leg.size);
        passivePos.balance += int64(leg.size);
        initiator.spotBalances[quoteCurrency] += notionalValue;
        passive.spotBalances[quoteCurrency] -= notionalValue + int64(order.liquidationFees);
      }

      // Pay fees to insurance fund, in case of partial liquidation
      bytes32 kuq = leg.assetID & KUQ_MASK;
      if (order.liquidationFees > 0) {
        (uint64 feeSubID, bool feeSubFound) = _getUintConfig2D(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID, kuq);
        require(feeSubFound, "fee account not found");
        _requireSubAccount(feeSubID).spotBalances[order.feeCurrency] += int64(order.liquidationFees);
      }
    }

    // Post trade validation, all parties should have equity >= 0
    _requireNonNegativeUsdValue(initiator);
    _requireNonNegativeUsdValue(passive);
  }

  function _requireValidMargin(SubAccount storage sub, bool isLiquidation, bool beforeTrade) internal view {
    (uint64 liquidationSubID, bool liquidationSubConfigured) = _getUintConfig(
      ConfigID.ADMIN_LIQUIDATION_SUB_ACCOUNT_ID
    );

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
    uint hi = uint(ConfigID.MAINTENANCE_MARGIN_TIER_12);
    uint lo = uint(ConfigID.MAINTENANCE_MARGIN_TIER_01);
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
    uint idx = 0;
    for (uint i = 1; i < configs.length; i++) {
      if (size.cmp(configs[i].size) < 0) {
        idx = i;
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

  /**
   * @dev Returns a BI value for a given configuration.
   * @param configID The configuration ID.
   * @param subkey The subkey for the configuration.
   * @return The BI value.
   */
  function _getCentibeepConfigBI(ConfigID configID, bytes32 subkey) internal view returns (BI memory) {
    (uint64 value, bool isSet) = _getUintConfig2D(configID, subkey);
    require(isSet, "Config not found");
    return BI(int256(uint256(value)), CENTIBEEP_DECIMALS);
  }

  /**
   * @dev Validate that the position size is reduced only. In other words:
   * -  If the position is long, 0 <= sizeAfterTrade <= sizeBeforeTrade
   * -  If the position is short, sizeBeforeTrade <= sizeAfterTrade <= 0
   *
   * @param oldSize The current balance of the position to check
   * @param sizeDelta The increment/decremenet of the position size
   */
  function _requireReduceOnly(int64 oldSize, int64 sizeDelta) private pure {
    int64 newSize = oldSize + sizeDelta;
    if (oldSize > 0) {
      require(newSize <= oldSize && newSize >= 0, "reduce only");
    } else {
      require(newSize >= oldSize && newSize <= 0, "reduce only");
    }
  }
}
