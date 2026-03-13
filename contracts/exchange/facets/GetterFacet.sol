pragma solidity ^0.8.20;

import "../api/RiskCheck.sol";
import "../api/MarginConfigContract.sol";
import "../api/CurrencyContract.sol";
import "../interfaces/IGetter.sol";

contract GetterFacet is IGetter, CurrencyContract, MarginConfigContractGetter, RiskCheck {
  using BIMath for BI;

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

  function getAccountSpotBalance(address accID, Currency currency) public view returns (int64) {
    Account storage account = state.accounts[accID];
    return account.spotBalances[currency];
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

  function getSubAccountSpotBalance(uint64 subAccountID, Currency currency) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.spotBalances[currency];
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

  function getExchangeCurrencyBalance(Currency currency) public view returns (int64) {
    return state.totalSpotBalances[currency];
  }

  function getInsuranceFundLoss(Currency currency) public view returns (int64) {
    require(currency == Currency.USDT, "Invalid currency");
    return _getInsuranceFundLossAmountUSDT();
  }

  function getTotalClientEquity(Currency currency) public view returns (int64) {
    require(currency == Currency.USDT, "Invalid currency");
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
}
