pragma solidity ^0.8.20;

import "../api/RiskCheck.sol";
import "../api/MarginConfigContract.sol";
import "../api/CurrencyContract.sol";
import "../interfaces/IGetter.sol";

contract GetterFacet is IGetter, CurrencyContract, MarginConfigContractGetter, RiskCheck {
  using BIMath for BI;

  uint64 internal constant MAX_PENDING_WITHDRAWAL_PAGE_SIZE = 100;

  function getAccountResult(address accID) public view returns (AccountResult memory) {
    Account storage account = state.accounts[accID];
    return
      AccountResult({
        id: account.id,
        multiSigThreshold: account.multiSigThreshold,
        adminCount: account.adminCount,
        subAccounts: account.subAccounts
      });
  }

  function isAllAccountExists(address[] calldata accountIDs) public view returns (bool) {
    for (uint256 i = 0; i < accountIDs.length; i++) {
      if (state.accounts[accountIDs[i]].id == address(0)) {
        return false;
      }
    }
    return true;
  }

  function getAccountFundingWalletBalance(address accID, uint8 currency) public view returns (int64) {
    Account storage account = state.accounts[accID];
    return account.fundingWalletBalances[currency];
  }

  function getAccountStake(
    address accID
  ) public view returns (int64 lockedAmount, int64 lockEndTime, int64 cooldownEndTime) {
    Account storage account = state.accounts[accID];
    return (account.stakeLockedAmount, account.stakeLockEndTime, account.stakeCooldownEndTime);
  }

  function isRecoveryAddress(address id, address signer, address recoveryAddress) public view returns (bool) {
    Account storage account = state.accounts[id];
    return addressExists(account.recoveryAddresses[signer], recoveryAddress);
  }

  function isOnboardedWithdrawalAddress(address id, address withdrawalAddress) public view returns (bool) {
    Account storage account = state.accounts[id];
    return account.onboardedWithdrawalAddresses[withdrawalAddress];
  }

  function getAccountOnboardedTransferAccount(address accID, address transferAccount) public view returns (bool) {
    Account storage account = state.accounts[accID];
    return account.onboardedTransferAccounts[transferAccount];
  }

  function getSignerPermission(address id, address signer) public view returns (uint64) {
    Account storage account = state.accounts[id];
    return account.signers[signer];
  }

  function getSessionValue(address sessionKey) public view returns (address, int64) {
    return (state.sessions[sessionKey].subAccountSigner, state.sessions[sessionKey].expiry);
  }

  function getConfig2D(ConfigID id, bytes32 subKey) public view returns (bytes32) {
    ConfigValue storage config = state.config2DValues[id][subKey];
    if (config.isSet) {
      return config.val;
    }
    return state.config2DValues[id][DEFAULT_CONFIG_ENTRY].val;
  }

  function config1DIsSet(ConfigID id) public view returns (bool) {
    return state.config1DValues[id].isSet;
  }

  function config2DIsSet(ConfigID id) public view returns (bool) {
    return state.config2DValues[id][DEFAULT_CONFIG_ENTRY].isSet;
  }

  function getConfig1D(ConfigID id) public view returns (bytes32) {
    return state.config1DValues[id].val;
  }

  function getConfigSchedule(ConfigID id, bytes32 subKey) public view returns (int64) {
    return state.configSettings[id].schedules[subKey].lockEndTime;
  }

  function isConfigScheduleAbsent(ConfigID id, bytes32 subKey) public view returns (bool) {
    return state.configSettings[id].schedules[subKey].lockEndTime == 0;
  }

  function getSubAccountResult(uint64 id) public view returns (SubAccountResult memory) {
    SubAccount storage subAccount = state.subAccounts[id];
    return
      SubAccountResult({
        id: subAccount.id,
        adminCount: subAccount.adminCount,
        signerCount: subAccount.signerCount,
        accountID: subAccount.accountID,
        marginType: subAccount.marginType,
        quoteCurrency: subAccount.quoteCurrency,
        lastAppliedFundingTimestamp: subAccount.lastAppliedFundingTimestamp
      });
  }

  function getSubAccSignerPermission(uint64 id, address signer) public view returns (uint64) {
    SubAccount storage subAccount = state.subAccounts[id];
    return subAccount.signers[signer];
  }

  function getFundingIndex(bytes32 assetID) public view returns (int64) {
    return state.prices.fundingIndex[assetID];
  }

  function getFundingTime() public view returns (int64) {
    return state.prices.fundingTime;
  }

  function getMarkPrice(bytes32 assetID) public view returns (uint64, bool) {
    return _getAssetPriceInQuote9Dec(assetID);
  }

  function getSettlementPrice(bytes32 assetID) public view returns (uint64, bool) {
    SettlementPriceEntry storage entry = state.prices.settlement[assetID];
    return (entry.value, entry.isSet);
  }

  function getInterestRate(bytes32 assetID) public view returns (int32) {
    return state.prices.interest[assetID];
  }

  function getSubAccountValue(uint64 subAccountID) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    uint64 quoteDecimals = _getBalanceDecimal(sub.quoteCurrency);
    return _getTotalEquityInQuote(sub).toInt64(quoteDecimals);
  }

  function getSubAccountPosition(
    uint64 subAccountID,
    bytes32 assetID
  ) public view returns (bool found, int64 balance, int64 lastAppliedFundingIndex, int64 marginBalance) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(assetID));
    Position storage pos = posmap.values[assetID];
    return (pos.id != 0x0, pos.balance, pos.lastAppliedFundingIndex, pos.marginBalance);
  }

  function getSubAccountPositionCount(uint64 subAccountID) public view returns (uint) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.perps.keys.length + sub.futures.keys.length + sub.options.keys.length;
  }

  function getSubAccountFuturesWalletBalance(uint64 subAccountID, uint8 currency) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.futuresWalletBalances[currency];
  }

  function getSubAccountSpotWalletBalance(uint64 subAccountID, uint8 currency) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.spotWalletBalances[currency];
  }

  function getSubAccountMode(uint64 subAccountID) public view returns (SubAccountMode) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.subAccountMode;
  }

  function getSimpleCrossMaintenanceMarginTiers(bytes32 kuq) public view returns (MarginTier[] memory) {
    uint64 qDec = _getBalanceDecimal(assetGetQuote(kuq));
    ListMarginTiersBIStorage storage tiersStorage = _getListMarginTiersBIStorageRef(kuq);
    MarginTier[] memory result = new MarginTier[](tiersStorage.tiers.length);
    for (uint i = 0; i < tiersStorage.tiers.length; i++) {
      result[i] = MarginTier({
        bracketStart: tiersStorage.tiers[i].bracketStart.toUint64(qDec),
        rate: SafeCast.toUint32(SafeCast.toUint256(tiersStorage.tiers[i].rate.toInt256(CENTIBEEP_DECIMALS)))
      });
    }
    return result;
  }

  function getSimpleCrossMaintenanceMarginTimelockEndTime(bytes32 kuq) public view returns (int64) {
    return state.simpleCrossMaintenanceMarginTimelockEndTime[kuq];
  }

  function getSubAccountMaintenanceMargin(uint64 subAccountID) public view returns (uint64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    uint qDec = _getBalanceDecimal(sub.quoteCurrency);
    return _getMaintenanceMarginCrossInQuote(sub).toUint64(qDec);
  }

  function hasOverdueWithdrawalRequest() public view returns (bool) {
    return _hasOverdueWithdrawalRequestAt(state.timestamp);
  }

  function hasOverdueWithdrawalRequestAt(int64 timestampNs) public view returns (bool) {
    return _hasOverdueWithdrawalRequestAt(timestampNs);
  }

  function getPendingWithdrawalQueueBounds() public view returns (uint64 head, uint64 tail) {
    WithdrawalQueue storage queue = state.pendingWithdrawalQueue;
    return (queue.head, queue.tail);
  }

  function getPendingWithdrawalRequests(
    uint64 start,
    uint64 limit
  ) public view returns (PendingWithdrawalRequest[] memory requests) {
    WithdrawalQueue storage queue = state.pendingWithdrawalQueue;
    uint64 head = queue.head;
    uint64 tail = queue.tail;

    if (start < head) {
      start = head;
    }
    if (start >= tail || limit == 0) {
      return new PendingWithdrawalRequest[](0);
    }

    require(limit <= MAX_PENDING_WITHDRAWAL_PAGE_SIZE, "limit too large");

    uint64 available = tail - start;
    uint64 count = limit < available ? limit : available;

    requests = new PendingWithdrawalRequest[](count);
    for (uint256 i; i < uint256(count); ++i) {
      requests[i] = queue.requests[start + uint64(i)];
    }
  }

  function getTimestamp() public view returns (int64) {
    return state.timestamp;
  }

  function getExchangeCurrencyBalance(uint8 currency) public view returns (int64) {
    return state.totalSpotBalances[currency];
  }

  function getInsuranceFundLoss(uint8 currency) public view returns (int64) {
    require(currency == CCY_USDT, "Invalid currency");
    return _getInsuranceFundLossAmountUSDT();
  }

  function getTotalClientEquity(uint8 currency) public view returns (int64) {
    require(currency == CCY_USDT, "Invalid currency");
    return _getTotalClientValueUSDT();
  }

  // Vault related getters
  function isVault(uint64 subAccountID) public view returns (bool) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.isVault;
  }

  function getVaultStatus(uint64 vaultID) public view returns (VaultStatus) {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");
    return sub.vaultInfo.status;
  }

  function getVaultFees(
    uint64 vaultID
  )
    public
    view
    returns (uint32 managementFeeCentiBeeps, uint32 performanceFeeCentiBeeps, uint32 marketingFeeCentiBeeps)
  {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");

    VaultInfo storage vaultInfo = sub.vaultInfo;
    return (vaultInfo.managementFeeCentiBeeps, vaultInfo.performanceFeeCentiBeeps, vaultInfo.marketingFeeCentiBeeps);
  }

  function getVaultTotalLpTokenSupply(uint64 vaultID) public view returns (uint64) {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");

    return sub.vaultInfo.totalLpTokenSupply;
  }

  function getVaultLpInfo(
    uint64 vaultID,
    address lpAccountID
  ) public view returns (uint64 lpTokenBalance, uint64 usdNotionalInvested) {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");

    VaultLpInfo storage lpInfo = sub.vaultInfo.lpInfos[lpAccountID];
    return (lpInfo.lpTokenBalance, lpInfo.usdNotionalInvested);
  }

  /// This function is more correctly named as isUnderDeriskMarginCross
  function isUnderDeriskMargin(uint64 subAccountID, bool expectedUnderDeriskMargin) public view returns (bool) {
    SubAccount storage subAccount = _requireSubAccount(subAccountID);
    return
      expectedUnderDeriskMargin ==
      isTotalEquityBelowDeriskMargin(
        subAccount,
        _getMaintenanceMarginCrossInQuote(subAccount),
        _getTotalEquityCrossInQuote(subAccount)
      );
  }

  function getCurrencyDecimals(uint16 id) public view returns (uint16) {
    return state.currencyConfigs[id].balanceDecimals;
  }

  function vaultIsCrossExchange(uint64 vaultID) public view returns (bool) {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");
    return sub.vaultInfo.isCrossExchange;
  }

  function getVaultManagerAttestedSharePrice(uint64 vaultID) public view returns (uint64) {
    SubAccount storage sub = _requireSubAccount(vaultID);
    require(sub.isVault, "Not a vault");
    return sub.vaultInfo.managerAttestedSharePrice;
  }

  function getAuthorizedBuilderConfig(
    address mainAccountID,
    address builderAccountID
  ) external view returns (uint64, uint64) {
    Account storage mainAccount = state.accounts[mainAccountID];
    BuilderFeeConfig storage cfg = mainAccount.builders[builderAccountID];
    return (cfg.maxFutureFeeRate, cfg.maxSpotFeeRate);
  }

  function getSubAccountPositionMarginConfig(
    uint64 subAccountID,
    bytes32 assetID
  ) external view returns (PositionMarginType, int32) {
    PositionMarginConfig storage cfg = _requireSubAccount(subAccountID).positionMarginConfigs[assetID];
    return (cfg.marginType, cfg.leverage);
  }

  ///////////////////////////////////////////////////////////////////
  /// MAM config getters (TRADE-1127)
  ///
  /// Typed reads for the per-currency MAM configs. The generic getConfig2D/getConfig1D
  /// already work; these mirror the existing typed-getter style and decode to the right
  /// type. The CENTIBEEP2D/UINT2D getters fall back to the DEFAULT_CONFIG_ENTRY (subKey 0)
  /// when no per-currency value is set (matching the underlying decoders); the BOOL2D
  /// getter reads the exact subKey (mirrors `_getBoolConfig2D`). CDC is store-only and
  /// exposed here for tooling/audit; nothing enforces it.
  ///////////////////////////////////////////////////////////////////

  /// @notice Spot asset Collateral Value Ratio (centi-beep, 1e6 = 100%). Read by the margin recompute.
  function getSpotAssetCVR(uint8 currency) external view returns (int32 cvr, bool isSet) {
    return _getCentibeepConfig2D(ConfigID.SPOT_ASSET_CVR, _currencyToConfig(currency));
  }

  /// @notice Spot asset CDC cap (native asset units). Store-only — not enforced on-chain.
  function getSpotAssetCDC(uint8 currency) external view returns (uint64 cap, bool isSet) {
    return _getUintConfig2D(ConfigID.SPOT_ASSET_CDC, _currencyToConfig(currency));
  }

  /// @notice Spot asset Margin Borrow Allowance (centi-beep). Store-only — enforcement is off-chain.
  function getSpotAssetMBA(uint8 currency) external view returns (int32 mba, bool isSet) {
    return _getCentibeepConfig2D(ConfigID.SPOT_ASSET_MBA, _currencyToConfig(currency));
  }

  /// @notice Whether a currency is disabled-by-default as collateral. Read by the [02] eligibility guard.
  function getDefaultDisabledCurrency(uint8 currency) external view returns (bool) {
    return _getBoolConfig2D(ConfigID.DEFAULT_DISABLED_CURRENCIES, _currencyToConfig(currency));
  }

  /// @notice Whether external main-account -> main-account transfers are blocked for a currency.
  /// Read by the transferMainToMain guard; true rejects the transfer for that currency.
  function getBlockTransferMainToMainCurrency(uint8 currency) external view returns (bool) {
    return _isBlockTransferMainToMainCurrency(currency);
  }

  /// @notice Whether a source main account is exempt from the main-to-main currency block.
  /// When true, the account's main-to-main transfers are allowed even for a blocked currency.
  function getBlockTransferMainToMainExemptAccount(address account) external view returns (bool) {
    return _isBlockTransferMainToMainExempt(account);
  }

  /// @notice Repayment floor ratio (centi-beep, 1D). Store-only.
  function getRepaymentFloorRatio() external view returns (int32 ratio, bool isSet) {
    return _getCentibeepConfig(ConfigID.REPAYMENT_FLOOR_RATIO);
  }

  /// @notice Liquidation repayment divisor (uint, 1D). Store-only.
  function getLiquidationRepaymentDivisor() external view returns (uint64 divisor, bool isSet) {
    return _getUintConfig(ConfigID.LIQUIDATION_REPAYMENT_DIVISOR);
  }

  /// @notice Automated repayment divisor (uint, 1D). Store-only.
  function getAutomatedRepaymentDivisor() external view returns (uint64 divisor, bool isSet) {
    return _getUintConfig(ConfigID.AUTOMATED_REPAYMENT_DIVISOR);
  }

  /// @notice Manual repayment divisor (uint, 1D). Store-only.
  function getManualRepaymentDivisor() external view returns (uint64 divisor, bool isSet) {
    return _getUintConfig(ConfigID.MANUAL_REPAYMENT_DIVISOR);
  }
}
