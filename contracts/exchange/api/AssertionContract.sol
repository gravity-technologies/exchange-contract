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
    Currency quoteCurrency,
    int64 lastAppliedFundingTimestamp
  ) external view {
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
    Currency quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp
  ) external view {
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
    if (assetIDs.length != expectedPrices.length) {
      revert AssertionArrayLengthMismatch();
    }

    for (uint256 i; i < assetIDs.length; ++i) {
      if (state.prices.mark[assetIDs[i]] != expectedPrices[i]) {
        revert AssertionMarkPriceMismatch();
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

    for (uint256 i; i < assetIDs.length; ++i) {
      if (state.prices.fundingIndex[assetIDs[i]] != expectedFundingIndexes[i]) {
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
    Currency currency,
    int64 expectedBalance,
    int64 expectedTotalSpotBalance
  ) external view {
    Account storage account = state.accounts[accountID];
    if (!state.replay.executed[txHash]) {
      revert AssertionDepositNotExecuted();
    }

    if (account.spotBalances[currency] != expectedBalance) {
      revert AssertionDepositBalanceMismatch();
    }

    if (state.totalSpotBalances[currency] != expectedTotalSpotBalance) {
      revert AssertionTotalSpotBalanceMismatch();
    }
  }

  function assertWithdraw(
    address fromAccID,
    Currency currency,
    int64 expectedBalance,
    uint64 feeSubAccId,
    int64 expectedFeeBalance,
    uint64 insuranceFundSubAccId,
    int64 expectedInsuranceFundBalance,
    int64 expectedTotalSpotBalance,
    SubAccountAssertion[] calldata subAccounts
  ) external view {
    Account storage account = state.accounts[fromAccID];
    if (account.spotBalances[currency] != expectedBalance) {
      revert AssertionWithdrawBalanceMismatch();
    }

    SubAccount storage feeSubAcc = state.subAccounts[feeSubAccId];
    if (feeSubAcc.spotBalances[currency] != expectedFeeBalance) {
      revert AssertionFeeBalanceMismatch();
    }

    SubAccount storage insuranceFundSubAcc = state.subAccounts[insuranceFundSubAccId];
    if (insuranceFundSubAcc.spotBalances[currency] != expectedInsuranceFundBalance) {
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
    Currency currency,
    SubAccountAssertion[] calldata subAccounts
  ) external view {
    if (fromSubID == 0) {
      Account storage fromAcc = state.accounts[fromAccID];
      if (fromAcc.spotBalances[currency] != expectedFromBalance) {
        revert AssertionFromAccountBalanceMismatch();
      }
    } else {
      SubAccount storage fromSub = state.subAccounts[fromSubID];
      if (fromSub.spotBalances[currency] != expectedFromBalance) {
        revert AssertionFromSubAccountBalanceMismatch();
      }
    }

    if (toSubID == 0) {
      Account storage toAcc = state.accounts[toAccID];
      if (toAcc.spotBalances[currency] != expectedToBalance) {
        revert AssertionToAccountBalanceMismatch();
      }
    } else {
      SubAccount storage toSub = state.subAccounts[toSubID];
      if (toSub.spotBalances[currency] != expectedToBalance) {
        revert AssertionToSubAccountBalanceMismatch();
      }
    }

    _assertSubAccounts(subAccounts);
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view {
    _assertSubAccounts(tradeAssertion.subAccounts);
  }

  function _assertSubAccounts(SubAccountAssertion[] calldata exSubs) internal view {
    for (uint256 i; i < exSubs.length; ++i) {
      _assertSubAccount(exSubs[i]);
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
    _assertSubAccountSpots(sub, exSub.spots);
  }

  function _assertSubAccountPositions(SubAccount storage sub, PositionAssertion[] calldata positions) internal view {
    for (uint256 j; j < positions.length; ++j) {
      PositionAssertion calldata exPos = positions[j];
      PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(exPos.assetID));
      Position storage pos = posmap.values[exPos.assetID];
      if (pos.balance != exPos.balance || pos.lastAppliedFundingIndex != exPos.fundingIndex) {
        revert AssertionSubPositionMismatch();
      }
    }
  }

  function _assertSubAccountSpots(SubAccount storage sub, SpotAssertion[] calldata spots) internal view {
    for (uint256 j; j < spots.length; ++j) {
      SpotAssertion calldata exSpot = spots[j];
      if (sub.spotBalances[exSpot.currency] != exSpot.balance) {
        revert AssertionSubSpotBalanceMismatch();
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

    for (uint256 i; i < tiersStorage.tiers.length; ++i) {
      MarginTierAssertion calldata exTier = expectedTiers[i];

      // Compare bracketStart
      uint256 qDec = _getBalanceDecimal(assetGetQuote(kud));
      if (tiersStorage.tiers[i].bracketStart.toUint64(qDec) != exTier.bracketStart) {
        revert AssertionSimpleCrossTierBracketMismatch();
      }

      // Compare rate
      if (tiersStorage.tiers[i].rate.toUint64(CENTIBEEP_DECIMALS) != uint64(exTier.rate)) {
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
      if (state.accounts[lpAssertion.accountID].spotBalances[exSpot.currency] != exSpot.balance) {
        revert AssertionVaultLpSpotMismatch();
      }
    }
  }

  function assertVaultCreate(
    uint64 vaultID,
    address managerAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    VaultCreateParamsAssertion calldata vaultParamsAssertion,
    int64 lastFeeSettlementTimestamp,
    uint64 totalLpTokenSupply,
    Currency initialInvestmentCurrency,
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
    if (vaultSub.spotBalances[initialInvestmentCurrency] != vaultInitialSpotBalance) {
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
    Currency investmentCurrency,
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
    if (vaultSub.spotBalances[investmentCurrency] != expectedVaultSpotBalance) {
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
    Currency currencyRedeemed,
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
    if (vaultSub.spotBalances[currencyRedeemed] != expectedVaultSpotBalance) {
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
}
