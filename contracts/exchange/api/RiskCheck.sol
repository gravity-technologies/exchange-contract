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
    int64 insuranceFundLossAmountUSDT = _getInsuranceFundLossAmountUSDT();
    if (insuranceFundLossAmountUSDT <= 0) {
      return 0;
    }

    uint usdtDec = _getBalanceDecimal(Currency.USDT);

    int64 totalClientValueUSDT = _getTotalClientValueUSDT();
    BI memory totalClientValueUSDTBI = BI(totalClientValueUSDT, usdtDec);
    BI memory insuranceFundLossAmountUSDTBI = BI(insuranceFundLossAmountUSDT, usdtDec);

    // result = withdrawAmount * (insuranceFundLoss / totalClientValue)
    BI memory withdrawAmountBI = BI(withdrawAmount, MAX_BALANCE_DECIMALS);
    BI memory result = withdrawAmountBI.mul(insuranceFundLossAmountUSDTBI).div(totalClientValueUSDTBI);
    return result.toUint64(MAX_BALANCE_DECIMALS);
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
      Account storage account = _requireAccount(state.bridgingPartners[i]);
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
      int64 insuranceFundValue = _getSubAccountValueInQuote(insuranceFund).toInt64(dec);
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

  function _requireValidMargin(SubAccount storage sub, bool isLiquidation, bool beforeTrade) internal view {
    (uint64 liquidationSubID, bool liquidationSubConfigured) = _getUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);

    // Insurance Fund can Trade when under MM, and in Negative Equity
    if (liquidationSubConfigured && sub.id == liquidationSubID) {
      return;
    }

    if (isLiquidation && beforeTrade) {
      require(!isAboveMaintenanceMargin(sub), "subaccount liquidated is above maintenance margin");
    } else if (!isLiquidation && !beforeTrade) {
      require(isAboveMaintenanceMargin(sub), "subaccount is below maintenance margin");
    }
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
    BI memory totalCharge = BI(0, 0);

    bytes32[] storage keys = subAccount.perps.keys;
    mapping(bytes32 => Position) storage values = subAccount.perps.values;
    uint numPerps = keys.length;
    for (uint i = 0; i < numPerps; i++) {
      bytes32 asset = keys[i];
      totalCharge = totalCharge.add(_getSimpleCrossFuturesMMUsd(asset, values[asset]));
    }

    return totalCharge;
  }

  function _getSimpleCrossFuturesMMUsd(bytes32 asset, Position storage position) internal view returns (BI memory) {
    BI memory markPrice = _requireAssetPriceBI(asset);

    int64 size = position.balance;
    if (size < 0) {
      size = -size;
    }
    BI memory sizeBI = BI(size, _getBalanceDecimal(assetGetUnderlying(asset)));

    bytes32 kuq = assetGetKUQ(asset);
    ListMarginTiersBI memory mt = _getListMarginTiersBIFromStorage(kuq);

    BI memory mm = _getPositionMM(mt, sizeBI, markPrice);
    BI memory qPrice = _getSpotPriceBI(assetGetQuote(asset));

    return mm.mul(qPrice);
  }
}
