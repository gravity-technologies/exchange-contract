pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./MarginConfigContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

uint64 constant DERISK_MM_RATIO_VAULT = 2_000_000; // 2x
uint64 constant DERISK_MM_RATIO_DEFAULT = 1_000_000; // 1x
uint256 constant DERISK_RATIO_DECIMALS = 6;
int64 constant DERISK_WINDOW_NANOS = 60 * 1_000_000_000; // 1 minute

contract RiskCheck is BaseContract, MarginConfigContractGetter {
  using BIMath for BI;

  /// @dev Only considers USDT spot balance for socialized loss calculation.
  /// Non-USDT currencies are excluded because socialized loss operates entirely in USDT terms.
  /// When only USDT is deposited, this produces bit-for-bit identical results to the old code
  /// because USDT→USDT conversion is the identity.
  function _getTotalClientValueUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(CCY_USDT);
    int64 totalSpotBalancesUSDTValue = BI(state.totalSpotBalances[CCY_USDT], dec).toInt64(dec);
    return totalSpotBalancesUSDTValue - _getTotalInternalValueUSDT() - _getTotalBridgingPartnerValueUSDT();
  }

  function _getTotalBridgingPartnerValueUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(CCY_USDT);
    BI memory totalValueBI = BI(0, dec);

    for (uint i = 0; i < state.bridgingPartners.length; ) {
      Account storage account = state.accounts[state.bridgingPartners[i]];
      if (account.id == address(0)) {
        // allow non-exist bridging partners, consider them to have 0 value
        unchecked { ++i; }
        continue;
      }

      totalValueBI = totalValueBI.add(_getFundingAccountEquityInUSDT(account));
      unchecked { ++i; }
    }
    return totalValueBI.toInt64(dec);
  }

  function _getTotalInternalValueUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(CCY_USDT);
    BI memory totalValueBI = BI(0, dec);

    address[] memory internalAccountAddresses = _getAllInternalFundingAccounts();
    for (uint i = 0; i < internalAccountAddresses.length; ) {
      if (internalAccountAddresses[i] == address(0)) {
        break;
      }
      Account storage account = _requireAccount(internalAccountAddresses[i]);
      totalValueBI = totalValueBI.add(_getFundingAccountEquityInUSDT(account));
      unchecked { ++i; }
    }

    return totalValueBI.toInt64(dec);
  }

  function _getAllInternalFundingAccounts() private view returns (address[] memory) {
    address[] memory accounts = new address[](2);

    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet) {
      _addUniqueAddress(accounts, insuranceFund.accountID);
    }

    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();
    if (isFeeSubAccIdSet) {
      _addUniqueAddress(accounts, feeSubAcc.accountID);
    }

    return accounts;
  }

  function _addUniqueAddress(address[] memory addresses, address newAddress) private pure {
    if (newAddress == address(0)) revert("Invalid address");

    for (uint256 i = 0; i < addresses.length; ) {
      if (addresses[i] == address(0)) {
        addresses[i] = newAddress;
        return;
      }
      if (addresses[i] == newAddress) return;
      unchecked { ++i; }
    }

    revert("mem array is full");
  }

  function _getInsuranceFundLossAmountUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(CCY_USDT);

    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet) {
      BI memory insuranceFundValueInQuoteBI = _getTotalEquityInQuote(insuranceFund);
      if (insuranceFundValueInQuoteBI.isNegative()) {
        BI memory insuranceFundValueInUSDT = _convertCurrency(
          insuranceFundValueInQuoteBI,
          insuranceFund.quoteCurrency,
          CCY_USDT
        );
        return -insuranceFundValueInUSDT.toInt64(dec);
      }
    }
    return 0;
  }

  /**
   * @dev Checks if an order is reducing the size of each position specified in its legs
   * @param sub The subaccount containing the positions
   * @param order The order to check
   * @return true if all legs of the order reduce their respective positions, false otherwise
   */
  function _isReducingOrder(
    SubAccount storage sub,
    Order calldata order,
    uint64[] memory matchedSizes
  ) internal view returns (bool) {
    for (uint256 i = 0; i < order.legs.length; ) {
      OrderLeg calldata leg = order.legs[i];
      int64 curSize = _getPositionCollection(sub, assetGetKind(leg.assetID)).values[leg.assetID].balance;
      int64 newSize = curSize + (leg.isBuyingAsset ? int64(matchedSizes[i]) : -int64(matchedSizes[i]));

      // Compare absolute sizes only
      int64 absCurSize = curSize < 0 ? -curSize : curSize;
      int64 absNewSize = newSize < 0 ? -newSize : newSize;

      if (absNewSize > absCurSize) {
        return false;
      }
      unchecked { ++i; }
    }
    return true;
  }

  /// @dev if isolatedAssetID != 0x0, this means we are checking MM for an isolated position
  function isBelowMaintenanceMargin(
    SubAccount storage subAccount,
    bytes32 isolatedAssetID
  ) internal view returns (bool) {
    if (subAccount.marginType != MarginType.SIMPLE_CROSS_MARGIN) {
      revert ErrInvalidSubAccountMarginType();
    }
    if (isolatedAssetID == bytes32(0)) {
      return _isBelowMaintenanceMarginCross(subAccount);
    }
    return _isBelowMaintenanceMarginIsolated(subAccount, isolatedAssetID);
  }

  function _isBelowMaintenanceMarginCross(SubAccount storage subAccount) private view returns (bool) {
    BI memory te = _getTotalEquityCrossInQuote(subAccount);
    if (te.val < 0) return true;
    return te.cmp(_getMaintenanceMarginCrossInQuote(subAccount)) < 0;
  }

  function _isBelowMaintenanceMarginIsolated(
    SubAccount storage subAccount,
    bytes32 assetID
  ) private view returns (bool) {
    BI memory te = _getTotalEquityIsolatedInQuote(subAccount, assetID);
    if (te.val < 0) return true;
    return te.cmp(_getMaintenanceMarginIsolatedInQuote(subAccount, assetID)) < 0;
  }

  function isTotalEquityCrossPositive(SubAccount storage subAccount) internal view returns (bool) {
    return _getTotalEquityCrossInQuote(subAccount).val > 0;
  }

  function _getMaintenanceMarginCrossInQuote(SubAccount storage subAccount) internal view returns (BI memory) {
    BI memory mmUSD = _getMaintenanceMarginCrossInUsd(subAccount);
    BI memory quotePriceUSD = _getSpotPriceUsdBI(subAccount.quoteCurrency);
    uint64 qDec = _getBalanceDecimal(subAccount.quoteCurrency);
    return mmUSD.div(quotePriceUSD).scale(qDec);
  }

  /**
   * @dev Returns the maintenance margin for a subaccount. Only support perpetual at the moment
   * @param subAccount The subaccount to check.
   * @return The maintenance margin in USD
   */
  function _getMaintenanceMarginCrossInUsd(SubAccount storage subAccount) internal view returns (BI memory) {
    BI memory totalCharge = BIMath.zero();

    bytes32[] storage keys = subAccount.perps.keys;
    mapping(bytes32 => Position) storage values = subAccount.perps.values;
    uint numPerps = keys.length;
    if (numPerps == 0) {
      return totalCharge;
    }
    mapping(bytes32 => PositionMarginConfig) storage posConfigs = subAccount.positionMarginConfigs;
    for (uint i = 0; i < numPerps; ) {
      bytes32 asset = keys[i];
      // Assumption: if there's no config for a position in this mapping, this means it is CROSS
      // This is to maintain backward compatibility since ISOLATED margin was added after CROSS
      if (posConfigs[asset].marginType == PositionMarginType.ISOLATED) {
        unchecked { ++i; }
        continue;
      }
      totalCharge = totalCharge.add(_getPerpMaintenanceMarginUSD(asset, values[asset]));
      unchecked { ++i; }
    }

    return totalCharge;
  }

  function _getPerpMaintenanceMarginUSD(bytes32 asset, Position storage position) internal view returns (BI memory) {
    BI memory markPrice = _requireAssetPriceInQuoteBI(asset);

    int64 size = position.balance;
    if (size < 0) {
      size = -size;
    }
    BI memory sizeBI = BI(size, _getBalanceDecimal(assetGetUnderlying(asset)));

    bytes32 kuq = assetGetKUQ(asset);
    ListMarginTiersBIStorage storage mtStorage = _getListMarginTiersBIStorageRef(kuq);

    BI memory mm = _getPositionMMFromStorage(mtStorage, sizeBI, markPrice);
    BI memory qPrice = _getSpotPriceUsdBI(assetGetQuote(asset));

    return mm.mul(qPrice);
  }

  /// if isolatedAssetID != 0x0, this means we are checking if an isolated position is deriskable
  function isDeriskable(
    int64 timestamp,
    SubAccount storage subAccount,
    bytes32 isolatedAssetID
  ) internal view returns (bool) {
    if (subAccount.isVault && subAccount.vaultInfo.status == VaultStatus.DELISTED) {
      return true;
    }

    if (subAccount.lastDeriskTimestamp + DERISK_WINDOW_NANOS > timestamp) {
      return true;
    }
    if (isolatedAssetID == 0x0) {
      return
        isTotalEquityBelowDeriskMargin(
          subAccount,
          _getMaintenanceMarginCrossInQuote(subAccount),
          _getTotalEquityCrossInQuote(subAccount)
        );
    }
    return
      isTotalEquityBelowDeriskMargin(
        subAccount,
        _getMaintenanceMarginIsolatedInQuote(subAccount, isolatedAssetID),
        _getTotalEquityIsolatedInQuote(subAccount, isolatedAssetID)
      );
  }

  // TODO: implement, only support perpetual at the moment
  function _getMaintenanceMarginIsolatedInQuote(
    SubAccount storage subAccount,
    bytes32 assetID
  ) internal view returns (BI memory) {
    Position storage pos = subAccount.perps.values[assetID];
    if (pos.id == 0x0) {
      revert ErrPositionNotFound();
    }
    BI memory mmUSD = _getPerpMaintenanceMarginUSD(assetID, pos);
    return _convertCurrency(mmUSD, CCY_USD, subAccount.quoteCurrency);
  }

  /// @dev Returns true if the sub account's total equity is below derisk margin
  ///      Fast-paths:
  ///      - If `subAccountTotalEquity` is negative, it is deriskable without computing the derisk margin.
  ///      Otherwise, checks `TE < DRM` where:
  ///      - `TE` is `subAccountTotalEquity` in quote decimals (negative TE is always deriskable).
  ///      - `DRM = maintenanceMargin * ratio`, with `ratio` chosen as:
  ///        vault: `DERISK_MM_RATIO_VAULT`, non-vault: `subAccount.deriskToMaintenanceMarginRatio` or default.
  function isTotalEquityBelowDeriskMargin(
    SubAccount storage subAccount,
    BI memory maintenanceMarginInQuote,
    BI memory totalEquityInQuote
  ) internal view returns (bool) {
    // Fast path: negative total equity is always deriskable (and avoids computing derisk margin).
    if (totalEquityInQuote.val < 0) {
      return true;
    }

    // Compute the derisk margin
    uint64 ratio;
    if (subAccount.isVault) {
      ratio = DERISK_MM_RATIO_VAULT;
    } else {
      ratio = subAccount.deriskToMaintenanceMarginRatio;
      if (ratio == 0) ratio = DERISK_MM_RATIO_DEFAULT;
    }

    BI memory deriskMarginInQuote = maintenanceMarginInQuote.mul(BI(int64(ratio), DERISK_RATIO_DECIMALS));

    // In contract, we omit the TE < MM check to allow derisk orders to proceed even when total equity
    // is below maintenance margin. This is intentional as it reduces risk for our insurance fund by
    // allowing accounts to reduce their positions even when they're in a risky state.
    // This differs from the liquidator's scan which uses MM <= TE < DRM condition to avoid interference
    // with liquidation process. For accounts outside derisking window, we only check TE < DRM.
    return totalEquityInQuote.cmp(deriskMarginInQuote) < 0;
  }
}
