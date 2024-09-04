// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./signature/generated/TradeSig.sol";
import "./RiskCheck.sol";
import "./ConfigContract.sol";
import "../util/BIMath.sol";

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
