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

  function _getSocializedLossHaircutAmount(address fromAccID, int64 withdrawAmount) internal view returns (uint64) {
    int64 insuranceFundLossAmountUSDT = _getInsuranceFundLossAmountUSDT();
    if (insuranceFundLossAmountUSDT == 0) {
      return 0;
    }

    // non-user accounts are not subject to socialized loss
    if (!_isUserAccount(fromAccID)) {
      return 0;
    }

    int64 totalClientValueUSDT = _getTotalClientValueUSDT();
    int haircutAmount = (int(withdrawAmount) * int(insuranceFundLossAmountUSDT)) / int(totalClientValueUSDT);
    return SafeCast.toUint64(SafeCast.toUint256(haircutAmount));
  }

  function _getTotalClientValueUSDT() internal view returns (int64) {
    BI memory totalSpotBalancesUSDTValueBI = _getBalanceValueInQuoteCurrencyBI(state.totalSpotBalances, Currency.USDT);
    int64 totalSpotBalancesUSDTValue = totalSpotBalancesUSDTValueBI.toInt64(_getBalanceDecimal(Currency.USDT));
    return totalSpotBalancesUSDTValue - _getTotalInternalValueUSDT() - _getTotalBridgingPartnerValueUSDT();
  }

  function _getTotalBridgingPartnerValueUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(Currency.USDT);
    BI memory totalValueBI = BI(0, dec);

    for (uint i = 0; i < state.bridgingPartners.length; i++) {
      Account storage account = state.accounts[state.bridgingPartners[i]];
      if (account.id == address(0)) {
        // allow non-exist bridging partners, consider them to have 0 value
        continue;
      }

      totalValueBI = totalValueBI.add(_getTotalAccountValueUSDT(account));
    }
    return totalValueBI.toInt64(dec);
  }

  function _getTotalInternalValueUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(Currency.USDT);
    BI memory totalValueBI = BI(0, dec);

    address[] memory internalAccountAddresses = _getAllInternalFundingAccounts();
    for (uint i = 0; i < internalAccountAddresses.length; i++) {
      if (internalAccountAddresses[i] == address(0)) {
        break;
      }
      Account storage account = _requireAccount(internalAccountAddresses[i]);
      totalValueBI = totalValueBI.add(_getTotalAccountValueUSDT(account));
    }

    return totalValueBI.toInt64(dec);
  }

  function _getAllInternalFundingAccounts() internal view returns (address[] memory) {
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

    for (uint256 i = 0; i < addresses.length; i++) {
      if (addresses[i] == address(0)) {
        addresses[i] = newAddress;
        return;
      }
      if (addresses[i] == newAddress) return;
    }

    revert("mem array is full");
  }

  function _getInsuranceFundLossAmountUSDT() internal view returns (int64) {
    uint dec = _getBalanceDecimal(Currency.USDT);

    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet) {
      BI memory insuranceFundValueInQuoteBI = _getSubAccountValueInQuote(insuranceFund);
      if (insuranceFundValueInQuoteBI.isNegative()) {
        BI memory insuranceFundValueInUSDT = _convertCurrency(
          insuranceFundValueInQuoteBI,
          insuranceFund.quoteCurrency,
          Currency.USDT
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
    for (uint256 i = 0; i < order.legs.length; i++) {
      OrderLeg calldata leg = order.legs[i];
      int64 curSize = _getPositionCollection(sub, assetGetKind(leg.assetID)).values[leg.assetID].balance;
      int64 newSize = curSize + (leg.isBuyingAsset ? int64(matchedSizes[i]) : -int64(matchedSizes[i]));

      if (curSize == 0 || (curSize > 0 ? (newSize < 0 || newSize >= curSize) : (newSize > 0 || newSize <= curSize))) {
        return false;
      }
    }
    return true;
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
    uint64 maintenanceMargin = _getMaintenanceMargin(subAccount);

    return subAccountValue >= 0 && uint64(subAccountValue) >= maintenanceMargin;
  }

  function isSubAccountValueNonNegative(SubAccount storage subAccount) internal view returns (bool) {
    return !_getSubAccountValueInQuote(subAccount).isNegative();
  }

  function _getMaintenanceMargin(SubAccount storage subAccount) internal view returns (uint64) {
    BI memory mmBI = _getSimpleCrossMMUsd(subAccount);
    BI memory settleIndexPrice = _getSpotPriceBI(subAccount.quoteCurrency);

    uint64 qDec = _getBalanceDecimal(subAccount.quoteCurrency);
    return mmBI.div(settleIndexPrice).toUint64(qDec);
  }

  /**
   * @dev Returns the maintenance margin for a subaccount.
   * @param subAccount The subaccount to check.
   * @return The maintenance margin.
   */
  function _getSimpleCrossMMUsd(SubAccount storage subAccount) internal view returns (BI memory) {
    BI memory totalCharge = BIMath.zero();

    bytes32[] storage keys = subAccount.perps.keys;
    mapping(bytes32 => Position) storage values = subAccount.perps.values;
    uint numPerps = keys.length;
    for (uint i = 0; i < numPerps; i++) {
      bytes32 asset = keys[i];
      totalCharge = totalCharge.add(_getPositionSimpleCrossMMUsd(asset, values[asset]));
    }

    return totalCharge;
  }

  function _getPositionSimpleCrossMMUsd(bytes32 asset, Position storage position) internal view returns (BI memory) {
    BI memory markPrice = _requireAssetPriceBI(asset);

    int64 size = position.balance;
    if (size < 0) {
      size = -size;
    }
    BI memory sizeBI = BI(size, _getBalanceDecimal(assetGetUnderlying(asset)));

    bytes32 kuq = assetGetKUQ(asset);
    ListMarginTiersBIStorage storage mtStorage = _getListMarginTiersBIStorageRef(kuq);

    BI memory mm = _getPositionMMFromStorage(mtStorage, sizeBI, markPrice);
    BI memory qPrice = _getSpotPriceBI(assetGetQuote(asset));

    return mm.mul(qPrice);
  }

  /// @dev compute the derisk margin in settle currency (and settle decimals), and return true if the subaccount is deriskable
  function _isDeriskable(int64 timestamp, SubAccount storage subAccount) internal view returns (bool) {
    if (subAccount.isVault && subAccount.vaultInfo.status == VaultStatus.DELISTED) {
      return true;
    }

    if (subAccount.lastDeriskTimestamp + DERISK_WINDOW_NANOS > timestamp) {
      return true;
    }

    // Compute the maintenance margin
    uint64 mm = _getMaintenanceMargin(subAccount);
    uint64 qDec = _getBalanceDecimal(subAccount.quoteCurrency);
    BI memory mmBI = BI(SafeCast.toInt256(uint(mm)), qDec);

    // Compute the derisk margin
    uint64 ratio = DERISK_MM_RATIO_DEFAULT;
    if (subAccount.isVault) {
      ratio = DERISK_MM_RATIO_VAULT;
    } else if (subAccount.deriskToMaintenanceMarginRatio != 0) {
      ratio = subAccount.deriskToMaintenanceMarginRatio;
    }

    BI memory ratioBI = BI(int64(ratio), DERISK_RATIO_DECIMALS);
    uint64 deriskMargin = mmBI.mul(ratioBI).toUint64(qDec);

    BI memory totalEquityBI = _getSubAccountValueInQuote(subAccount);
    int64 totalEquity = totalEquityBI.toInt64(qDec);

    // In contract, we omit the TE < MM check to allow derisk orders to proceed even when total equity
    // is below maintenance margin. This is intentional as it reduces risk for our insurance fund by
    // allowing accounts to reduce their positions even when they're in a risky state.
    // This differs from the liquidator's scan which uses MM <= TE < DRM condition to avoid interference
    // with liquidation process. For accounts outside derisking window, we only check TE < DRM.
    return totalEquity < 0 || uint64(totalEquity) < deriskMargin;
  }
}
