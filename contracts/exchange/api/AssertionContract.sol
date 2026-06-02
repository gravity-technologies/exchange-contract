pragma solidity ^0.8.20;

import "./AssertionError.sol";
import "./RiskCheck.sol";
import "../types/PositionMap.sol";
import "../types/DataStructure.sol";
import "./ConfigContract.sol";
import "../interfaces/IAssertion.sol";

contract AssertionContract is IAssertion, ConfigContract, RiskCheck {
  using BIMath for BI;

  function assertLastTxID(uint64 expectedLastTxID) external view {
    if (state.lastTxID != expectedLastTxID) {
      revert AssertionLastTxIdMismatch();
    }
  }

  // Assertions for Account Contract
  function assertCreateAccount(address accountID, address signer) external view {
    Account storage account = state.accounts[accountID];
    if (
      account.id != accountID ||
      account.multiSigThreshold != 1 ||
      account.adminCount != 1 ||
      account.subAccounts.length != 0
    ) {
      revert AssertionCreateAccountMismatch();
    }

    if (account.signers[signer] != AccountPermAdmin) {
      revert AssertionSignerNotAdmin();
    }
  }

  function assertCreateAccountWithSubAccount(
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    uint8 quoteCurrency,
    int64 lastAppliedFundingTimestamp
  ) external view {
    _assertCreateAccountWithSubAccountBase(accountID, subAccountID, marginType, quoteCurrency, lastAppliedFundingTimestamp);
  }

  function assertCreateAccountWithSubAccountV2(
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    uint8 quoteCurrency,
    int64 lastAppliedFundingTimestamp,
    SubAccountMode subAccountMode
  ) external view {
    _assertCreateAccountWithSubAccountBase(accountID, subAccountID, marginType, quoteCurrency, lastAppliedFundingTimestamp);

    SubAccount storage sub = state.subAccounts[subAccountID];
    if (sub.subAccountMode != subAccountMode) {
      revert AssertionCreateSubAccountMismatch();
    }
  }

  function _assertCreateAccountWithSubAccountBase(
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    uint8 quoteCurrency,
    int64 lastAppliedFundingTimestamp
  ) private view {
    // Verify account creation
    Account storage account = state.accounts[accountID];
    if (
      account.id != accountID ||
      account.multiSigThreshold != 1 ||
      account.adminCount != 1 ||
      account.subAccounts.length != 1
    ) {
      revert AssertionCreateAccountWithSubMismatch();
    }

    // Verify signer permissions
    if (account.signers[accountID] != AccountPermAdmin) {
      revert AssertionSignerNotAdmin();
    }

    // Verify subaccount creation
    SubAccount storage sub = state.subAccounts[subAccountID];
    if (
      sub.id != subAccountID ||
      sub.accountID != accountID ||
      sub.quoteCurrency != quoteCurrency ||
      sub.marginType != marginType ||
      sub.lastAppliedFundingTimestamp != lastAppliedFundingTimestamp
    ) {
      revert AssertionCreateSubAccountMismatch();
    }

    // Verify subaccount is linked to account
    if (account.subAccounts[0] != subAccountID) {
      revert AssertionSubAccountNotLinked();
    }
  }

  function assertSetAccountMultiSigThreshold(address accountID, uint8 expectedThreshold) external view {
    if (state.accounts[accountID].multiSigThreshold != expectedThreshold) {
      revert AssertionMultiSigThresholdMismatch();
    }
  }

  function assertAddAccountSigner(
    address accountID,
    address signer,
    uint64 expectedPermissions,
    uint256 adminCount
  ) external view {
    Account storage acc = state.accounts[accountID];
    if (acc.signers[signer] != expectedPermissions) {
      revert AssertionSignerPermissionsMismatch();
    }

    if (acc.adminCount != adminCount) {
      revert AssertionAdminCountMismatch();
    }
  }

  function assertRemoveAccountSigner(address accountID, address signer, uint256 adminCount) external view {
    Account storage acc = state.accounts[accountID];
    if (acc.signers[signer] != 0) {
      revert AssertionSignerNotRemoved();
    }

    if (acc.adminCount != adminCount) {
      revert AssertionAdminCountMismatch();
    }
  }

  function assertAddWithdrawalAddress(address accountID, address withdrawalAddress) external view {
    Account storage acc = state.accounts[accountID];
    if (!acc.onboardedWithdrawalAddresses[withdrawalAddress]) {
      revert AssertionWithdrawalAddressNotAdded();
    }
  }

  function assertRemoveWithdrawalAddress(address accountID, address withdrawalAddress) external view {
    Account storage acc = state.accounts[accountID];
    if (acc.onboardedWithdrawalAddresses[withdrawalAddress]) {
      revert AssertionWithdrawalAddressNotRemoved();
    }
  }

  function assertAddTransferAccount(address accountID, address transferAccountID) external view {
    Account storage acc = state.accounts[accountID];
    if (!acc.onboardedTransferAccounts[transferAccountID]) {
      revert AssertionTransferAccountNotAdded();
    }
  }

  function assertRemoveTransferAccount(address accountID, address transferAccountID) external view {
    Account storage acc = state.accounts[accountID];
    if (acc.onboardedTransferAccounts[transferAccountID]) {
      revert AssertionTransferAccountNotRemoved();
    }
  }

  // Assertions for SubAccount Contract
  function assertCreateSubAccount(
    uint64 subAccountID,
    address accountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp
  ) external view {
    _assertCreateSubAccountBase(subAccountID, accountID, quoteCurrency, marginType, lastAppliedFundingTimestamp);
  }

  function assertCreateSubAccountV2(
    uint64 subAccountID,
    address accountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    SubAccountMode subAccountMode
  ) external view {
    _assertCreateSubAccountBase(subAccountID, accountID, quoteCurrency, marginType, lastAppliedFundingTimestamp);

    SubAccount storage sub = state.subAccounts[subAccountID];
    if (sub.subAccountMode != subAccountMode) {
      revert AssertionCreateSubAccountMismatch();
    }
  }

  function _assertCreateSubAccountBase(
    uint64 subAccountID,
    address accountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp
  ) private view {
    SubAccount storage sub = state.subAccounts[subAccountID];
    if (
      sub.id != subAccountID ||
      sub.accountID != accountID ||
      sub.quoteCurrency != quoteCurrency ||
      sub.marginType != marginType ||
      sub.lastAppliedFundingTimestamp != lastAppliedFundingTimestamp
    ) {
      revert AssertionCreateSubAccountMismatch();
    }

    // Check if the subAccountID appears in account.subAccounts
    Account storage acc = state.accounts[accountID];
    bool found = false;
    uint256 subsLen = acc.subAccounts.length;
    for (uint256 i; i < subsLen; ++i) {
      if (acc.subAccounts[i] == subAccountID) {
        found = true;
        break;
      }
    }
    if (!found) {
      revert AssertionSubIdNotInAccount();
    }
  }

  function assertSetSubAccountMarginType(uint64 subAccountID, MarginType expectedMarginType) external view {
    if (state.subAccounts[subAccountID].marginType != expectedMarginType) {
      revert AssertionMarginTypeMismatch();
    }
  }

  function assertAddSubAccountSigner(uint64 subAccountID, address signer, uint64 expectedPermissions) external view {
    if (state.subAccounts[subAccountID].signers[signer] != expectedPermissions) {
      revert AssertionSubAccountSignerPermissionMismatch();
    }
  }

  function assertRemoveSubAccountSigner(uint64 subAccountID, address signer) external view {
    if (state.subAccounts[subAccountID].signers[signer] != 0) {
      revert AssertionSubAccountSignerNotRemoved();
    }
  }

  function assertAddSessionKey(address sessionKey, address expectedSigner, int64 expectedExpiry) external view {
    Session storage session = state.sessions[sessionKey];
    if (session.subAccountSigner != expectedSigner || session.expiry != expectedExpiry) {
      revert AssertionSessionKeyMismatch();
    }
  }

  function assertRemoveSessionKey(address sessionKey) external view {
    if (state.sessions[sessionKey].expiry != 0) {
      revert AssertionSessionKeyNotRemoved();
    }

    if (state.sessions[sessionKey].subAccountSigner != address(0)) {
      revert AssertionSubAccountSignerMismatch();
    }
  }

  // Assertions for Oracle Contract
  function assertMarkPriceTick(bytes32[] calldata assetIDs, uint64[] calldata expectedPrices) external view {
    uint256 len = assetIDs.length;
    if (len != expectedPrices.length) {
      revert AssertionArrayLengthMismatch();
    }

    mapping(bytes32 => uint64) storage mark = state.prices.mark;
    for (uint256 i; i < len; ) {
      if (mark[assetIDs[i]] != expectedPrices[i]) {
        revert AssertionMarkPriceMismatch();
      }

      unchecked {
        ++i;
      }
    }
  }

  function assertFundingPriceTick(
    bytes32[] calldata assetIDs,
    int64[] calldata expectedFundingIndexes,
    int64 expectedFundingTime
  ) external view {
    if (assetIDs.length != expectedFundingIndexes.length) {
      revert AssertionArrayLengthMismatch();
    }

    if (state.prices.fundingTime != expectedFundingTime) {
      revert AssertionFundingTimeMismatch();
    }

    mapping(bytes32 => int64) storage fundingIndex = state.prices.fundingIndex;
    for (uint256 i; i < assetIDs.length; ++i) {
      if (fundingIndex[assetIDs[i]] != expectedFundingIndexes[i]) {
        revert AssertionFundingIndexMismatch();
      }
    }
  }

  // Assertions for Config Contract
  function assertScheduleConfig(ConfigID key, bytes32 subKey, int64 expectedLockEndTime) external view {
    ConfigSetting storage setting = state.configSettings[key];
    ConfigSchedule storage sched = setting.schedules[subKey];
    if (sched.lockEndTime != expectedLockEndTime) {
      revert AssertionLockEndTimeMismatch();
    }
  }

  function assertSetConfig(
    ConfigID key,
    bytes32 subKey,
    bytes32 expectedValue,
    address[] calldata bridgingPartners
  ) external view {
    _assertSetConfig(key, subKey, expectedValue);
    _assertSameAddresses(state.bridgingPartners, bridgingPartners);
  }

  function assertInitializeConfig(
    InitializeConfigItem[] calldata items,
    address[] calldata bridgingPartners
  ) external view {
    for (uint256 i; i < items.length; ++i) {
      InitializeConfigItem calldata item = items[i];
      _assertSetConfig(item.key, item.subKey, item.value);
    }
    _assertSameAddresses(state.bridgingPartners, bridgingPartners);
  }

  function _assertSetConfig(ConfigID key, bytes32 subKey, bytes32 expectedValue) internal view {
    ConfigSetting storage setting = state.configSettings[key];
    if (setting.schedules[subKey].lockEndTime != 0) {
      revert AssertionScheduleNotDeleted();
    }

    bool is2DConfig = uint256(setting.typ) % 2 == 0;
    ConfigValue storage config = is2DConfig ? state.config2DValues[key][subKey] : state.config1DValues[key];
    if (!config.isSet) {
      revert AssertionConfigNotSet();
    }

    if (config.val != expectedValue) {
      revert AssertionConfigValueMismatch();
    }
  }

  // Assertions for Transfer Contract
  function assertDeposit(
    bytes32 txHash,
    address accountID,
    uint8 currency,
    int64 expectedBalance,
    int64 expectedTotalSpotBalance
  ) external view {
    Account storage account = state.accounts[accountID];
    if (!state.replay.executed[txHash]) {
      revert AssertionDepositNotExecuted();
    }

    if (account.fundingWalletBalances[currency] != expectedBalance) {
      revert AssertionDepositBalanceMismatch();
    }

    if (state.totalSpotBalances[currency] != expectedTotalSpotBalance) {
      revert AssertionTotalSpotBalanceMismatch();
    }
  }

  function assertWithdraw(
    address fromAccID,
    uint8 currency,
    int64 expectedBalance,
    uint64 feeSubAccId,
    int64 expectedFeeBalance,
    uint64 insuranceFundSubAccId,
    int64 expectedInsuranceFundBalance,
    int64 expectedTotalSpotBalance,
    SubAccountAssertion[] calldata subAccounts
  ) external view {
    Account storage account = state.accounts[fromAccID];
    if (account.fundingWalletBalances[currency] != expectedBalance) {
      revert AssertionWithdrawBalanceMismatch();
    }

    // USDT fees go to futures wallet, non-USDT fees go to spot wallet
    SubAccount storage feeSubAcc = state.subAccounts[feeSubAccId];
    int64 actualFeeBalance = currency == CCY_USDT
      ? feeSubAcc.futuresWalletBalances[currency]
      : feeSubAcc.spotWalletBalances[currency];
    if (actualFeeBalance != expectedFeeBalance) {
      revert AssertionFeeBalanceMismatch();
    }

    SubAccount storage insuranceFundSubAcc = state.subAccounts[insuranceFundSubAccId];
    if (insuranceFundSubAcc.futuresWalletBalances[currency] != expectedInsuranceFundBalance) {
      revert AssertionInsuranceFundBalanceMismatch();
    }

    if (state.totalSpotBalances[currency] != expectedTotalSpotBalance) {
      revert AssertionTotalSpotBalanceMismatch();
    }

    _assertSubAccounts(subAccounts);
  }

  function assertTransfer(
    address fromAccID,
    address toAccID,
    uint64 fromSubID,
    uint64 toSubID,
    int64 expectedFromBalance,
    int64 expectedToBalance,
    uint8 currency,
    SubAccountAssertion[] calldata subAccounts
  ) external view {
    if (fromSubID == 0) {
      Account storage fromAcc = state.accounts[fromAccID];
      if (fromAcc.fundingWalletBalances[currency] != expectedFromBalance) {
        revert AssertionFromAccountBalanceMismatch();
      }
    } else {
      SubAccount storage fromSub = state.subAccounts[fromSubID];
      if (fromSub.futuresWalletBalances[currency] != expectedFromBalance) {
        revert AssertionFromSubAccountBalanceMismatch();
      }
    }

    if (toSubID == 0) {
      Account storage toAcc = state.accounts[toAccID];
      if (toAcc.fundingWalletBalances[currency] != expectedToBalance) {
        revert AssertionToAccountBalanceMismatch();
      }
    } else {
      SubAccount storage toSub = state.subAccounts[toSubID];
      if (toSub.futuresWalletBalances[currency] != expectedToBalance) {
        revert AssertionToSubAccountBalanceMismatch();
      }
    }

    _assertSubAccounts(subAccounts);
  }

  function assertTransferV2(
    address fromAccID,
    address toAccID,
    uint64 fromSubID,
    uint64 toSubID,
    int64 expectedFromBalance,
    int64 expectedToBalance,
    uint8 currency,
    WalletType fromWalletType,
    WalletType toWalletType,
    SubAccountAssertionV2[] calldata subAccounts
  ) external view {
    if (_getWalletBalance(fromAccID, fromSubID, fromWalletType, currency) != expectedFromBalance) {
      revert AssertionFromAccountBalanceMismatch();
    }
    if (_getWalletBalance(toAccID, toSubID, toWalletType, currency) != expectedToBalance) {
      revert AssertionToAccountBalanceMismatch();
    }

    _assertSubAccountsV2(subAccounts);
  }

  function _getWalletBalance(
    address accID,
    uint64 subID,
    WalletType wt,
    uint8 currency
  ) private view returns (int64) {
    if (wt == WalletType.FUNDING) return state.accounts[accID].fundingWalletBalances[currency];
    if (wt == WalletType.FUTURES) return state.subAccounts[subID].futuresWalletBalances[currency];
    if (wt == WalletType.SPOT) return state.subAccounts[subID].spotWalletBalances[currency];
    revert("unsupported wallet type");
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view {
    _assertSubAccounts(tradeAssertion.subAccounts);

    AccountAssertion[] calldata accounts = tradeAssertion.accounts;
    uint256 accountsLen = accounts.length;
    for (uint256 i; i < accountsLen; ) {
      _assertAccount(accounts[i]);

      unchecked {
        ++i;
      }
    }
  }

  function assertTradeV2(TradeAssertionV2 calldata tradeAssertion) external view {
    _assertSubAccountsV2(tradeAssertion.subAccounts);

    AccountAssertion[] calldata accounts = tradeAssertion.accounts;
    uint256 accountsLen = accounts.length;
    for (uint256 i; i < accountsLen; ) {
      _assertAccount(accounts[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _assertSubAccounts(SubAccountAssertion[] calldata exSubs) internal view {
    uint256 len = exSubs.length;
    for (uint256 i; i < len; ) {
      _assertSubAccount(exSubs[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _assertSubAccount(SubAccountAssertion calldata exSub) internal view {
    SubAccount storage sub = state.subAccounts[exSub.subAccountID];

    if (sub.lastAppliedFundingTimestamp != exSub.fundingTimestamp) {
      revert AssertionSubFundingTimestampMismatch();
    }

    if (sub.lastDeriskTimestamp != exSub.lastDeriskTimestamp) {
      revert AssertionSubDeriskTimestampMismatch();
    }

    _assertSubAccountPositions(sub, exSub.positions);
    _assertSubAccountFuturesWalletBalances(sub, exSub.spots);
  }

  function _assertAccount(AccountAssertion calldata exAcc) internal view {
    mapping(uint8 => int64) storage spots = state.accounts[exAcc.accountID].fundingWalletBalances;
    SpotAssertion[] calldata exSpots = exAcc.spots;
    uint256 length = exSpots.length;
    for (uint256 i; i < length; ) {
      SpotAssertion calldata exSpot = exSpots[i];
      if (spots[exSpot.currency] != exSpot.balance) {
        revert AssertAccountSpotBalanceMismatch();
      }

      unchecked {
        ++i;
      }
    }
  }

  function _assertSubAccountPositions(SubAccount storage sub, PositionAssertion[] calldata positions) internal view {
    uint256 posLen = positions.length;
    for (uint256 j; j < posLen; ) {
      PositionAssertion calldata exPos = positions[j];
      PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(exPos.assetID));
      Position storage pos = posmap.values[exPos.assetID];
      if (pos.balance != exPos.balance) {
        revert AssertionSubPositionBalanceMismatch(sub.id, exPos.assetID, exPos.balance, pos.balance);
      }
      if (pos.lastAppliedFundingIndex != exPos.fundingIndex) {
        revert AssertionSubPositionFundingIndexMismatch(
          sub.id,
          exPos.assetID,
          exPos.fundingIndex,
          pos.lastAppliedFundingIndex
        );
      }
      if (pos.marginBalance != exPos.marginBalance) {
        revert AssertionSubPositionMarginBalanceMismatch(sub.id, exPos.assetID, exPos.marginBalance, pos.marginBalance);
      }

      unchecked {
        ++j;
      }
    }
  }

  function _assertSubAccountFuturesWalletBalances(SubAccount storage sub, SpotAssertion[] calldata spots) internal view {
    uint256 spotsLen = spots.length;
    for (uint256 j; j < spotsLen; ) {
      SpotAssertion calldata exSpot = spots[j];
      if (sub.futuresWalletBalances[exSpot.currency] != exSpot.balance) {
        revert AssertionSubSpotBalanceMismatch();
      }

      unchecked {
        ++j;
      }
    }
  }

  function _assertSubAccountsV2(SubAccountAssertionV2[] calldata exSubs) internal view {
    uint256 len = exSubs.length;
    for (uint256 i; i < len; ) {
      _assertSubAccountV2(exSubs[i]);

      unchecked {
        ++i;
      }
    }
  }

  function _assertSubAccountV2(SubAccountAssertionV2 calldata exSub) internal view {
    SubAccount storage sub = state.subAccounts[exSub.subAccountID];

    if (sub.lastAppliedFundingTimestamp != exSub.fundingTimestamp) {
      revert AssertionSubFundingTimestampMismatch();
    }

    if (sub.lastDeriskTimestamp != exSub.lastDeriskTimestamp) {
      revert AssertionSubDeriskTimestampMismatch();
    }

    _assertSubAccountPositions(sub, exSub.positions);
    _assertSubAccountFuturesWalletBalances(sub, exSub.futuresWalletSpots);
    _assertSubAccountSpotWalletBalances(sub, exSub.spotWalletSpots);
  }

  function _assertSubAccountSpotWalletBalances(SubAccount storage sub, SpotAssertion[] calldata spots) internal view {
    uint256 spotsLen = spots.length;
    for (uint256 j; j < spotsLen; ) {
      SpotAssertion calldata exSpot = spots[j];
      if (sub.spotWalletBalances[exSpot.currency] != exSpot.balance) {
        revert AssertionSubSpotBalanceMismatch();
      }

      unchecked {
        ++j;
      }
    }
  }

  // Assertions for WalletRecovery Contract
  function assertAddRecoveryAddress(
    address accountID,
    address signer,
    address[] calldata recoveryAddresses
  ) external view {
    Account storage acc = state.accounts[accountID];
    _assertSameAddresses(acc.recoveryAddresses[signer], recoveryAddresses);
  }

  function assertRemoveRecoveryAddress(
    address accountID,
    address signer,
    address[] calldata recoveryAddresses
  ) external view {
    Account storage acc = state.accounts[accountID];
    _assertSameAddresses(acc.recoveryAddresses[signer], recoveryAddresses);
  }

  function assertRecoverAddress(
    address accID,
    address oldSigner,
    address newSigner,
    uint64 mainAccountPermission,
    uint64[] calldata subAccountIDs,
    uint64[] calldata subAccountPermissions,
    address[] calldata recoveryAddresses
  ) external view {
    Account storage acc = _requireAccount(accID);

    // Assert account signer changes
    if (acc.signers[newSigner] != mainAccountPermission) {
      revert AssertionNewSignerNotAdded();
    }

    if (acc.signers[oldSigner] != 0) {
      revert AssertionOldSignerNotRemoved();
    }

    // Assert subAccount signer changes
    if (subAccountIDs.length != acc.subAccounts.length) {
      revert AssertionSubAccountIdsLengthMismatch();
    }

    if (subAccountIDs.length != subAccountPermissions.length) {
      revert AssertionSubAccountPermissionsLengthMismatch();
    }

    uint256 numSubAccs = acc.subAccounts.length;
    for (uint256 i = 0; i < numSubAccs; i++) {
      SubAccount storage subAcc = _requireSubAccount(subAccountIDs[i]);
      if (subAcc.signers[newSigner] != subAccountPermissions[i]) {
        revert AssertionNewSignerSubPermissionsMismatch();
      }

      if (subAcc.signers[oldSigner] != 0) {
        revert AssertionOldSignerSubPermissionsMismatch();
      }
    }

    _assertSameAddresses(acc.recoveryAddresses[newSigner], recoveryAddresses);

    if (acc.recoveryAddresses[oldSigner].length != 0) {
      revert AssertionOldSignerRecoveryAddressesNotCleared();
    }

    if (addressExists(acc.recoveryAddresses[newSigner], newSigner)) {
      revert AssertionNewSignerStillInRecovery();
    }
  }

  function _assertSameAddresses(address[] storage arr1, address[] calldata arr2) internal view {
    if (arr1.length != arr2.length) {
      revert AssertionArrayLengthMismatchStrict();
    }

    for (uint256 i = 0; i < arr1.length; i++) {
      if (!addressExists(arr2, arr1[i])) {
        revert AssertionAddressMissingFromFirstArray();
      }
    }
    for (uint256 i = 0; i < arr2.length; i++) {
      if (!addressExists(arr1, arr2[i])) {
        revert AssertionAddressMissingFromSecondArray();
      }
    }
  }

  // Assertions for MarginConfig Contract
  function assertSetSimpleCrossMMTiers(bytes32 kud, MarginTierAssertion[] calldata expectedTiers) external view {
    ListMarginTiersBIStorage storage tiersStorage = _getListMarginTiersBIStorageRef(kud);
    if (tiersStorage.tiers.length != expectedTiers.length) {
      revert AssertionSimpleCrossTierLengthMismatch();
    }

    if (state.simpleCrossMaintenanceMarginTimelockEndTime[kud] != 0) {
      revert AssertionSimpleCrossTierScheduleActive();
    }

    uint256 qDec = _getBalanceDecimal(assetGetQuote(kud));
    for (uint256 i; i < tiersStorage.tiers.length; ++i) {
      MarginTierAssertion calldata exTier = expectedTiers[i];
      MarginTierBIStorage storage tier = tiersStorage.tiers[i];

      // Compare bracketStart
      if (tier.bracketStart.toUint64(qDec) != exTier.bracketStart) {
        revert AssertionSimpleCrossTierBracketMismatch();
      }

      // Compare rate
      if (tier.rate.toUint64(CENTIBEEP_DECIMALS) != uint64(exTier.rate)) {
        revert AssertionSimpleCrossTierRateMismatch();
      }
    }
  }

  function assertScheduleSimpleCrossMMTiers(bytes32 kud, int64 expectedLockEndTime) external view {
    if (state.simpleCrossMaintenanceMarginTimelockEndTime[kud] != expectedLockEndTime) {
      revert AssertionSimpleCrossScheduleMismatch();
    }
  }

  // Helper functions for vault assertions
  function _assertVaultLp(SubAccount storage vaultSub, VaultLpAssertion calldata lpAssertion) internal view {
    // Check LP token info
    VaultLpInfo storage lpInfo = vaultSub.vaultInfo.lpInfos[lpAssertion.accountID];
    if (
      lpInfo.lpTokenBalance != lpAssertion.lpTokenBalance ||
      lpInfo.usdNotionalInvested != lpAssertion.usdNotionalInvested
    ) {
      revert AssertionVaultLpInfoMismatch();
    }

    // Check spot balance
    for (uint256 j; j < lpAssertion.spots.length; ++j) {
      SpotAssertion calldata exSpot = lpAssertion.spots[j];
      if (state.accounts[lpAssertion.accountID].fundingWalletBalances[exSpot.currency] != exSpot.balance) {
        revert AssertionVaultLpSpotMismatch();
      }
    }
  }

  function assertVaultCreate(
    uint64 vaultID,
    address managerAccountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    VaultCreateParamsAssertion calldata vaultParamsAssertion,
    int64 lastFeeSettlementTimestamp,
    uint64 totalLpTokenSupply,
    uint8 initialInvestmentCurrency,
    int64 vaultInitialSpotBalance,
    VaultLpAssertion calldata managerAssertion,
    SubAccountAssertion calldata vaultSubAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];

    // Check vault properties
    if (
      vaultSub.id != vaultID ||
      vaultSub.accountID != managerAccountID ||
      vaultSub.quoteCurrency != quoteCurrency ||
      vaultSub.marginType != marginType ||
      vaultSub.lastAppliedFundingTimestamp != lastAppliedFundingTimestamp ||
      !vaultSub.isVault
    ) {
      revert AssertionVaultCreateMismatch();
    }

    // Check vault info properties
    {
      VaultInfo storage vaultInfo = vaultSub.vaultInfo;
      if (
        vaultInfo.status != VaultStatus.ACTIVE ||
        vaultInfo.managementFeeCentiBeeps != vaultParamsAssertion.managementFeeCentiBeeps ||
        vaultInfo.performanceFeeCentiBeeps != vaultParamsAssertion.performanceFeeCentiBeeps ||
        vaultInfo.marketingFeeCentiBeeps != vaultParamsAssertion.marketingFeeCentiBeeps ||
        vaultInfo.lastFeeSettlementTimestamp != lastFeeSettlementTimestamp ||
        vaultInfo.totalLpTokenSupply != totalLpTokenSupply ||
        vaultInfo.isCrossExchange != vaultParamsAssertion.isCrossExchange ||
        vaultInfo.managerAttestedSharePrice != vaultParamsAssertion.managerAttestedSharePrice
      ) {
        revert AssertionVaultInfoMismatch();
      }
    }

    // Check vault spot balance
    if (vaultSub.futuresWalletBalances[initialInvestmentCurrency] != vaultInitialSpotBalance) {
      revert AssertionVaultCreateSpotBalanceMismatch();
    }

    // Check manager's LP state
    _assertVaultLp(vaultSub, managerAssertion);

    _assertSubAccount(vaultSubAssertion);
  }

  function assertVaultUpdate(uint64 vaultID, VaultUpdateParamsAssertion calldata vaultParamsAssertion) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    if (
      vaultInfo.managementFeeCentiBeeps != vaultParamsAssertion.managementFeeCentiBeeps ||
      vaultInfo.performanceFeeCentiBeeps != vaultParamsAssertion.performanceFeeCentiBeeps ||
      vaultInfo.marketingFeeCentiBeeps != vaultParamsAssertion.marketingFeeCentiBeeps
    ) {
      revert AssertionVaultUpdateMismatch();
    }
  }

  function assertVaultDelist(uint64 vaultID) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    if (vaultSub.vaultInfo.status != VaultStatus.DELISTED) {
      revert AssertionVaultDelistMismatch();
    }
  }

  function assertVaultClose(uint64 vaultID) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    if (vaultSub.vaultInfo.status != VaultStatus.CLOSED) {
      revert AssertionVaultCloseMismatch();
    }
  }

  function assertVaultInvest(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    uint8 investmentCurrency,
    int64 expectedVaultSpotBalance,
    VaultLpAssertion calldata investorAssertion,
    SubAccountAssertion calldata vaultSubAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    // Check total LP token supply
    if (vaultSub.vaultInfo.totalLpTokenSupply != expectedTotalLpTokenSupply) {
      revert AssertionVaultInvestTotalSupplyMismatch();
    }

    // Check vault spot balance
    if (vaultSub.futuresWalletBalances[investmentCurrency] != expectedVaultSpotBalance) {
      revert AssertionVaultInvestSpotBalanceMismatch();
    }

    // Check investor's LP state
    _assertVaultLp(vaultSub, investorAssertion);

    _assertSubAccount(vaultSubAssertion);
  }

  function assertVaultBurnLpToken(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    VaultLpAssertion calldata lpAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    // Check total LP token supply
    if (vaultSub.vaultInfo.totalLpTokenSupply != expectedTotalLpTokenSupply) {
      revert AssertionVaultBurnTotalSupplyMismatch();
    }

    // Check LP state
    _assertVaultLp(vaultSub, lpAssertion);
  }

  function assertVaultRedeem(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    uint8 currencyRedeemed,
    int64 expectedVaultSpotBalance,
    VaultLpAssertion calldata redeemingLpAssertion,
    VaultLpAssertion calldata managerAssertion,
    VaultLpAssertion calldata feeAccountAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    // Check total LP token supply
    if (vaultSub.vaultInfo.totalLpTokenSupply != expectedTotalLpTokenSupply) {
      revert AssertionVaultRedeemTotalSupplyMismatch();
    }

    // Check vault spot balance
    if (vaultSub.futuresWalletBalances[currencyRedeemed] != expectedVaultSpotBalance) {
      revert AssertionVaultRedeemSpotBalanceMismatch();
    }

    // Check all LP states
    _assertVaultLp(vaultSub, redeemingLpAssertion);
    _assertVaultLp(vaultSub, managerAssertion);

    if (feeAccountAssertion.accountID != address(0)) {
      _assertVaultLp(vaultSub, feeAccountAssertion);
    }
  }

  function assertVaultManagementFeeTick(
    uint64 vaultID,
    int64 expectedLastFeeSettlementTimestamp,
    uint64 expectedTotalLpTokenSupply,
    VaultLpAssertion calldata managerAssertion,
    VaultLpAssertion calldata feeAccountAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    if (!vaultSub.isVault) {
      revert AssertionNotVault();
    }

    // Check last fee settlement timestamp
    if (vaultSub.vaultInfo.lastFeeSettlementTimestamp != expectedLastFeeSettlementTimestamp) {
      revert AssertionVaultFeeTickTimestampMismatch();
    }

    // Check total LP token supply
    if (vaultSub.vaultInfo.totalLpTokenSupply != expectedTotalLpTokenSupply) {
      revert AssertionVaultFeeTickTotalSupplyMismatch();
    }

    // Check LP states
    _assertVaultLp(vaultSub, managerAssertion);

    if (feeAccountAssertion.accountID != address(0)) {
      _assertVaultLp(vaultSub, feeAccountAssertion);
    }
  }

  function assertSetDeriskToMaintenanceMarginRatio(
    uint64 subAccountID,
    uint32 expectedDeriskToMaintenanceMarginRatio
  ) external view {
    if (state.subAccounts[subAccountID].deriskToMaintenanceMarginRatio != expectedDeriskToMaintenanceMarginRatio) {
      revert AssertionDeriskRatioMismatch();
    }
  }

  function assertAddCurrency(uint16 id, uint16 balanceDecimals) external view {
    CurrencyConfig storage config = state.currencyConfigs[id];
    if (config.id != id || config.balanceDecimals != balanceDecimals) {
      revert AssertionCurrencyConfigMismatch();
    }
  }

  function assertVaultCrossExchangeUpdate(uint64 vaultID, uint64 expectedManagerAttestedSharePrice) external view {
    if (state.subAccounts[vaultID].vaultInfo.managerAttestedSharePrice != expectedManagerAttestedSharePrice) {
      revert AssertionVaultCrossExchangeUpdateMismatch();
    }
  }

  function assertUpdateFundingInfo(AssetFundingInfo[] calldata expectedFundingInfos) external view {
    mapping(bytes32 => FundingInfo) storage actualConfigs = state.fundingConfigs;
    for (uint256 i; i < expectedFundingInfos.length; ++i) {
      AssetFundingInfo calldata exp = expectedFundingInfos[i];
      FundingInfo storage act = actualConfigs[exp.asset];
      if (
        act.updateTime != exp.updateTime ||
        act.fundingRateHighCentiBeeps != exp.fundingRateHighCentiBeeps ||
        act.fundingRateLowCentiBeeps != exp.fundingRateLowCentiBeeps ||
        act.intervalHours != exp.intervalHours
      ) {
        revert AssertionFundingInfoMismatch();
      }
    }
  }

  function assertSetSubAccountPositionMarginConfig(
    uint64 subID,
    bytes32 asset,
    PositionMarginType marginType,
    int32 leverage
  ) external view {
    PositionMarginConfig storage cfg = state.subAccounts[subID].positionMarginConfigs[asset];
    if (cfg.marginType != marginType || cfg.leverage != leverage) {
      revert SubAccountPositionMarginMismatch();
    }
  }

  function assertAddIsolatedPositionMargin(
    uint64 subAccountID,
    bytes32 assetID,
    int64 positionMargin,
    int64 subAccountSpotBalance
  ) external view {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    if (sub.futuresWalletBalances[sub.quoteCurrency] != subAccountSpotBalance) {
      revert AssertionSubSpotBalanceMismatch();
    }
    Position storage pos = _getPosition(sub, assetID);
    if (pos.marginBalance != positionMargin) {
      revert AssertionPositionMarginMismatch();
    }
  }

  function assertAuthorizeBuilder(
    address mainAccountID,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate
  ) external view {
    Account storage mainAccount = _requireAccount(mainAccountID);
    BuilderFeeConfig storage builderFee = mainAccount.builders[builderAccountID];
    if (builderFee.maxFutureFeeRate != maxFutureFeeRate || builderFee.maxSpotFeeRate != maxSpotFeeRate) {
      revert AssertionBuilderFeeConfigMismatch();
    }
  }

  function assertAddAccountSignerWithBuilder(
    address accountID,
    address signer,
    uint64 expectedPermissions,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate,
    uint256 adminCount
  ) external view {
    Account storage acc = state.accounts[accountID];

    // Assert signer permissions (from assertAddAccountSigner)
    if (acc.signers[signer] != expectedPermissions) {
      revert AssertionSignerPermissionsMismatch();
    }

    if (acc.adminCount != adminCount) {
      revert AssertionAdminCountMismatch();
    }

    // Assert builder fee config (from assertAuthorizeBuilder)
    BuilderFeeConfig storage builderFee = acc.builders[builderAccountID];
    if (builderFee.maxFutureFeeRate != maxFutureFeeRate || builderFee.maxSpotFeeRate != maxSpotFeeRate) {
      revert AssertionBuilderFeeConfigMismatch();
    }
  }

  function assertStake(
    address accountID,
    uint8 currency,
    int64 expectedFundingBalance,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view {
    Account storage acc = state.accounts[accountID];
    _assertStakeInfo(accountID, acc, expectedLockedAmount, expectedLockEndTime, expectedCooldownEndTime);
    _assertStakeFundingBalance(accountID, acc, currency, expectedFundingBalance);
  }

  function assertInitiateUnstake(
    address accountID,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view {
    _assertStakeInfo(
      accountID,
      state.accounts[accountID],
      expectedLockedAmount,
      expectedLockEndTime,
      expectedCooldownEndTime
    );
  }

  function assertCancelUnstake(
    address accountID,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view {
    _assertStakeInfo(
      accountID,
      state.accounts[accountID],
      expectedLockedAmount,
      expectedLockEndTime,
      expectedCooldownEndTime
    );
  }

  function assertWithdrawStake(
    address accountID,
    uint8 currency,
    int64 expectedFundingBalance,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view {
    Account storage acc = state.accounts[accountID];
    _assertStakeInfo(accountID, acc, expectedLockedAmount, expectedLockEndTime, expectedCooldownEndTime);
    _assertStakeFundingBalance(accountID, acc, currency, expectedFundingBalance);
  }

  function _assertStakeInfo(
    address accountID,
    Account storage acc,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) private view {
    if (acc.stakeLockedAmount != expectedLockedAmount) {
      revert AssertionStakeLockedAmountMismatch(accountID, expectedLockedAmount, acc.stakeLockedAmount);
    }
    if (acc.stakeLockEndTime != expectedLockEndTime) {
      revert AssertionStakeLockEndTimeMismatch(accountID, expectedLockEndTime, acc.stakeLockEndTime);
    }
    if (acc.stakeCooldownEndTime != expectedCooldownEndTime) {
      revert AssertionStakeCooldownEndTimeMismatch(accountID, expectedCooldownEndTime, acc.stakeCooldownEndTime);
    }
  }

  function _assertStakeFundingBalance(
    address accountID,
    Account storage acc,
    uint8 currency,
    int64 expectedFundingBalance
  ) private view {
    if (acc.fundingWalletBalances[currency] != expectedFundingBalance) {
      revert AssertionStakeFundingBalanceMismatch(
        accountID,
        currency,
        expectedFundingBalance,
        acc.fundingWalletBalances[currency]
      );
    }
  }
}
