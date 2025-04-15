pragma solidity ^0.8.20;

import "./RiskCheck.sol";
import "../types/PositionMap.sol";
import "../types/DataStructure.sol";
import "./ConfigContract.sol";

contract AssertionContract is ConfigContract, RiskCheck {
  using BIMath for BI;

  function assertLastTxID(uint64 expectedLastTxID) external view {
    require(state.lastTxID == expectedLastTxID, "ex lastTxID");
  }

  // Assertions for Account Contract
  function assertCreateAccount(address accountID, address signer) external view {
    Account storage account = state.accounts[accountID];
    require(
      account.id == accountID &&
        account.multiSigThreshold == 1 &&
        account.adminCount == 1 &&
        account.subAccounts.length == 0,
      "ex createAcc"
    );

    require(account.signers[signer] == AccountPermAdmin, "ex signerNotAdmin");
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
    require(
      account.id == accountID &&
        account.multiSigThreshold == 1 &&
        account.adminCount == 1 &&
        account.subAccounts.length == 1,
      "ex createAccWithSub"
    );

    // Verify signer permissions
    require(account.signers[accountID] == AccountPermAdmin, "ex signerNotAdmin");

    // Verify subaccount creation
    SubAccount storage sub = state.subAccounts[subAccountID];
    require(
      sub.id == subAccountID &&
        sub.accountID == accountID &&
        sub.quoteCurrency == quoteCurrency &&
        sub.marginType == marginType &&
        sub.lastAppliedFundingTimestamp == lastAppliedFundingTimestamp,
      "ex createSubAcc"
    );

    // Verify subaccount is linked to account
    require(account.subAccounts[0] == subAccountID, "ex subAccountNotLinked");
  }

  function assertSetAccountMultiSigThreshold(address accountID, uint8 expectedThreshold) external view {
    require(state.accounts[accountID].multiSigThreshold == expectedThreshold, "ex multiSigThreshold");
  }

  function assertAddAccountSigner(
    address accountID,
    address signer,
    uint64 expectedPermissions,
    uint adminCount
  ) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.signers[signer] == expectedPermissions, "ex signerPermissions");
    require(acc.adminCount == adminCount, "ex adminCount");
  }

  function assertRemoveAccountSigner(address accountID, address signer, uint adminCount) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.signers[signer] == 0, "ex signerNotRemoved");
    require(acc.adminCount == adminCount, "ex adminCount");
  }

  function assertAddWithdrawalAddress(address accountID, address withdrawalAddress) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.onboardedWithdrawalAddresses[withdrawalAddress] == true, "ex withdrawalAddrNotAdded");
  }

  function assertRemoveWithdrawalAddress(address accountID, address withdrawalAddress) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.onboardedWithdrawalAddresses[withdrawalAddress] == false, "ex withdrawalAddrNotRemoved");
  }

  function assertAddTransferAccount(address accountID, address transferAccountID) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.onboardedTransferAccounts[transferAccountID] == true, "ex transferAccNotAdded");
  }

  function assertRemoveTransferAccount(address accountID, address transferAccountID) external view {
    Account storage acc = state.accounts[accountID];
    require(acc.onboardedTransferAccounts[transferAccountID] == false, "ex transferAccNotRemoved");
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
    require(
      sub.id == subAccountID &&
        sub.accountID == accountID &&
        sub.quoteCurrency == quoteCurrency &&
        sub.marginType == marginType &&
        sub.lastAppliedFundingTimestamp == lastAppliedFundingTimestamp,
      "ex createSubAcc"
    );
    // Check if the subAccountID appears in account.subAccounts
    Account storage acc = state.accounts[accountID];
    bool found = false;
    uint subsLen = acc.subAccounts.length;
    for (uint i; i < subsLen; ++i) {
      if (acc.subAccounts[i] == subAccountID) {
        found = true;
        break;
      }
    }
    require(found, "ex subIDNotInAccount");
  }

  function assertSetSubAccountMarginType(uint64 subAccountID, MarginType expectedMarginType) external view {
    require(state.subAccounts[subAccountID].marginType == expectedMarginType, "ex marginType");
  }

  function assertAddSubAccountSigner(uint64 subAccountID, address signer, uint64 expectedPermissions) external view {
    require(state.subAccounts[subAccountID].signers[signer] == expectedPermissions, "ex subAccSignerPerm");
  }

  function assertRemoveSubAccountSigner(uint64 subAccountID, address signer) external view {
    require(state.subAccounts[subAccountID].signers[signer] == 0, "ex subAccSignerNotRemoved");
  }

  function assertAddSessionKey(address sessionKey, address expectedSigner, int64 expectedExpiry) external view {
    Session storage session = state.sessions[sessionKey];
    require(session.subAccountSigner == expectedSigner && session.expiry == expectedExpiry, "ex sessionKey");
  }

  function assertRemoveSessionKey(address sessionKey) external view {
    require(state.sessions[sessionKey].expiry == 0, "ex sessionKeyNotRemoved");
    require(state.sessions[sessionKey].subAccountSigner == address(0), "ex subAccountSigner");
  }

  // Assertions for Oracle Contract
  function assertMarkPriceTick(bytes32[] calldata assetIDs, uint64[] calldata expectedPrices) external view {
    require(assetIDs.length == expectedPrices.length, "ex arrayLengthMismatch");
    for (uint i; i < assetIDs.length; ++i) {
      require(state.prices.mark[assetIDs[i]] == expectedPrices[i], "ex markPriceMismatch");
    }
  }

  function assertFundingPriceTick(
    bytes32[] calldata assetIDs,
    int64[] calldata expectedFundingIndexes,
    int64 expectedFundingTime
  ) external view {
    require(assetIDs.length == expectedFundingIndexes.length, "ex arrayLengthMismatch");
    require(state.prices.fundingTime == expectedFundingTime, "ex fundingTimeMismatch");
    for (uint i; i < assetIDs.length; ++i) {
      require(state.prices.fundingIndex[assetIDs[i]] == expectedFundingIndexes[i], "ex fundingIndexMismatch");
    }
  }

  // Assertions for Config Contract
  function assertScheduleConfig(ConfigID key, bytes32 subKey, int64 expectedLockEndTime) external view {
    ConfigSetting storage setting = state.configSettings[key];
    ConfigSchedule storage sched = setting.schedules[subKey];
    require(sched.lockEndTime == expectedLockEndTime, "ex lockEndTime");
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
    for (uint i; i < items.length; ++i) {
      InitializeConfigItem calldata item = items[i];
      _assertSetConfig(item.key, item.subKey, item.value);
    }
    _assertSameAddresses(state.bridgingPartners, bridgingPartners);
  }

  function _assertSetConfig(ConfigID key, bytes32 subKey, bytes32 expectedValue) internal view {
    ConfigSetting storage setting = state.configSettings[key];
    require(setting.schedules[subKey].lockEndTime == 0, "ex scheduleNotDeleted");

    bool is2DConfig = uint256(setting.typ) % 2 == 0;
    ConfigValue storage config = is2DConfig ? state.config2DValues[key][subKey] : state.config1DValues[key];
    require(config.isSet, "ex configNotSet");
    require(config.val == expectedValue, "ex configValueMismatch");
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
    require(state.replay.executed[txHash], "ex depositExcuted");
    require(account.spotBalances[currency] == expectedBalance, "ex depositBalance");
    require(state.totalSpotBalances[currency] == expectedTotalSpotBalance, "ex totalSpotBalance");
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
    require(account.spotBalances[currency] == expectedBalance, "ex withdrawBalance");
    SubAccount storage feeSubAcc = state.subAccounts[feeSubAccId];
    require(feeSubAcc.spotBalances[currency] == expectedFeeBalance, "ex feeBalance");
    SubAccount storage insuranceFundSubAcc = state.subAccounts[insuranceFundSubAccId];
    require(insuranceFundSubAcc.spotBalances[currency] == expectedInsuranceFundBalance, "ex insuranceFundBalance");
    require(state.totalSpotBalances[currency] == expectedTotalSpotBalance, "ex totalSpotBalance");

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
      require(fromAcc.spotBalances[currency] == expectedFromBalance, "ex fromBalance");
    } else {
      SubAccount storage fromSub = state.subAccounts[fromSubID];
      require(fromSub.spotBalances[currency] == expectedFromBalance, "ex fromSubBalance");
    }

    if (toSubID == 0) {
      Account storage toAcc = state.accounts[toAccID];
      require(toAcc.spotBalances[currency] == expectedToBalance, "ex toBalance");
    } else {
      SubAccount storage toSub = state.subAccounts[toSubID];
      require(toSub.spotBalances[currency] == expectedToBalance, "ex toSubBalance");
    }

    _assertSubAccounts(subAccounts);
  }

  struct PositionAssertion {
    bytes32 assetID;
    int64 balance;
    int64 fundingIndex;
  }
  struct SpotAssertion {
    Currency currency;
    int64 balance;
  }
  struct SubAccountAssertion {
    uint64 subAccountID;
    int64 fundingTimestamp;
    PositionAssertion[] positions;
    SpotAssertion[] spots;
  }
  struct TradeAssertion {
    SubAccountAssertion[] subAccounts;
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view {
    _assertSubAccounts(tradeAssertion.subAccounts);
  }

  function _assertSubAccounts(SubAccountAssertion[] calldata exSubs) internal view {
    for (uint i; i < exSubs.length; ++i) {
      _assertSubAccount(exSubs[i]);
    }
  }

  function _assertSubAccount(SubAccountAssertion calldata exSub) internal view {
    SubAccount storage sub = state.subAccounts[exSub.subAccountID];

    // Assert funding timestamp
    require(sub.lastAppliedFundingTimestamp == exSub.fundingTimestamp, "exSub - fundingTimeMismatch");

    // Assert positions
    for (uint j; j < exSub.positions.length; ++j) {
      PositionAssertion calldata exPos = exSub.positions[j];
      PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(exPos.assetID));
      Position storage pos = posmap.values[exPos.assetID];
      require(
        pos.balance == exPos.balance && pos.lastAppliedFundingIndex == exPos.fundingIndex,
        "exSub - positionMismatch"
      );
    }

    // Assert spot balances
    for (uint j; j < exSub.spots.length; ++j) {
      SpotAssertion calldata exSpot = exSub.spots[j];
      require(sub.spotBalances[exSpot.currency] == exSpot.balance, "exSub - spotMismatch");
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
    require(acc.signers[newSigner] == mainAccountPermission, "ex newSignerNotAdded");
    require(acc.signers[oldSigner] == 0, "ex oldSignerNotRemoved");

    // Assert subAccount signer changes
    require(subAccountIDs.length == acc.subAccounts.length, "ex subAccountIDs length");
    require(subAccountIDs.length == subAccountPermissions.length, "ex subAccount permissions");

    uint256 numSubAccs = acc.subAccounts.length;
    for (uint256 i = 0; i < numSubAccs; i++) {
      SubAccount storage subAcc = _requireSubAccount(subAccountIDs[i]);
      require(subAcc.signers[newSigner] == subAccountPermissions[i], "ex newSigner subPermAdded");
      require(subAcc.signers[oldSigner] == 0, "ex oldSigner subPermRemoved");
    }

    _assertSameAddresses(acc.recoveryAddresses[newSigner], recoveryAddresses);

    require(acc.recoveryAddresses[oldSigner].length == 0, "ex oldSigner recovery addresses not cleared");
    require(!addressExists(acc.recoveryAddresses[newSigner], newSigner), "ex newSigner still in recovery addresses");
  }

  function _assertSameAddresses(address[] storage arr1, address[] calldata arr2) internal view {
    require(arr1.length == arr2.length, "ex array length mismatch");
    for (uint256 i = 0; i < arr1.length; i++) {
      require(addressExists(arr2, arr1[i]), "ex address not found in array1");
    }
    for (uint256 i = 0; i < arr2.length; i++) {
      require(addressExists(arr1, arr2[i]), "ex address not found in array2");
    }
  }

  struct MarginTierAssertion {
    uint64 bracketStart;
    uint32 rate;
  }

  // Assertions for MarginConfig Contract
  function assertSetSimpleCrossMMTiers(bytes32 kud, MarginTierAssertion[] calldata expectedTiers) external view {
    ListMarginTiersBI memory tiers = _getListMarginTiersBIFromStorage(kud);
    require(tiers.tiers.length == expectedTiers.length, "ex setSimpleCrossMMLenMismatch");
    require(state.simpleCrossMaintenanceMarginTimelockEndTime[kud] == 0, "ex setSimpleCrossMMNotScheduled");

    for (uint i; i < tiers.tiers.length; ++i) {
      MarginTierAssertion calldata exTier = expectedTiers[i];
      MarginTierBI memory tier = tiers.tiers[i];

      // Compare bracketStart
      BI memory bracketStart = tier.bracketStart;
      uint qDec = _getBalanceDecimal(assetGetQuote(kud));
      require(bracketStart.toUint64(qDec) == exTier.bracketStart, "ex setSimpleCrossMMTierBracket");

      // Compare rate
      BI memory rate = tier.rate;
      require(rate.toUint64(CENTIBEEP_DECIMALS) == uint64(exTier.rate), "ex setSimpleCrossMMTierRate");
    }
  }

  function assertScheduleSimpleCrossMMTiers(bytes32 kud, int64 expectedLockEndTime) external view {
    require(
      state.simpleCrossMaintenanceMarginTimelockEndTime[kud] == expectedLockEndTime,
      "ex schedSimpleCrossMMTiers"
    );
  }

  // Vault assertion structs
  struct VaultLpAssertion {
    address accountID;
    uint64 lpTokenBalance;
    uint64 usdNotionalInvested;
    SpotAssertion[] spots;
  }

  // Helper functions for vault assertions
  function _assertVaultLp(
    SubAccount storage vaultSub,
    VaultLpAssertion calldata lpAssertion,
    string memory errorPrefix
  ) internal view {
    // Check LP token info
    VaultLpInfo storage lpInfo = vaultSub.vaultInfo.lpInfos[lpAssertion.accountID];
    require(
      lpInfo.lpTokenBalance == lpAssertion.lpTokenBalance &&
        lpInfo.usdNotionalInvested == lpAssertion.usdNotionalInvested,
      string.concat(errorPrefix, " - lpInfo")
    );

    // Check spot balance
    for (uint j; j < lpAssertion.spots.length; ++j) {
      SpotAssertion calldata exSpot = lpAssertion.spots[j];
      require(
        state.accounts[lpAssertion.accountID].spotBalances[exSpot.currency] == exSpot.balance,
        string.concat(errorPrefix, " - spotMismatch")
      );
    }
  }

  function assertVaultCreate(
    uint64 vaultID,
    address managerAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps,
    int64 lastFeeSettlementTimestamp,
    uint64 totalLpTokenSupply,
    Currency initialInvestmentCurrency,
    int64 vaultInitialSpotBalance,
    VaultLpAssertion calldata managerAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];

    // Check vault properties
    require(
      vaultSub.id == vaultID &&
        vaultSub.accountID == managerAccountID &&
        vaultSub.quoteCurrency == quoteCurrency &&
        vaultSub.marginType == marginType &&
        vaultSub.lastAppliedFundingTimestamp == lastFeeSettlementTimestamp &&
        vaultSub.isVault == true,
      "ex vaultCreate"
    );

    // Check vault info properties
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    require(
      vaultInfo.status == VaultStatus.ACTIVE &&
        vaultInfo.managementFeeCentiBeeps == managementFeeCentiBeeps &&
        vaultInfo.performanceFeeCentiBeeps == performanceFeeCentiBeeps &&
        vaultInfo.marketingFeeCentiBeeps == marketingFeeCentiBeeps &&
        vaultInfo.lastFeeSettlementTimestamp == lastFeeSettlementTimestamp &&
        vaultInfo.totalLpTokenSupply == totalLpTokenSupply,
      "ex vaultCreateInfo"
    );

    // Check vault spot balance
    require(
      vaultSub.spotBalances[initialInvestmentCurrency] == vaultInitialSpotBalance,
      "ex vaultCreateVaultSpotBalance"
    );

    // Check manager's LP state
    _assertVaultLp(vaultSub, managerAssertion, "ex vaultCreateManager");
  }

  function assertVaultUpdate(
    uint64 vaultID,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    require(vaultSub.isVault, "ex notVault");

    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    require(
      vaultInfo.managementFeeCentiBeeps == managementFeeCentiBeeps &&
        vaultInfo.performanceFeeCentiBeeps == performanceFeeCentiBeeps &&
        vaultInfo.marketingFeeCentiBeeps == marketingFeeCentiBeeps,
      "ex vaultUpdate"
    );
  }

  function assertVaultDelist(uint64 vaultID) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    require(vaultSub.isVault, "ex notVault");
    require(vaultSub.vaultInfo.status == VaultStatus.DELISTED, "ex vaultDelist");
  }

  function assertVaultClose(uint64 vaultID) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    require(vaultSub.isVault, "ex notVault");
    require(vaultSub.vaultInfo.status == VaultStatus.CLOSED, "ex vaultClose");
  }

  function assertVaultInvest(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    Currency investmentCurrency,
    int64 expectedVaultSpotBalance,
    VaultLpAssertion calldata investorAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    require(vaultSub.isVault, "ex notVault");

    // Check total LP token supply
    require(vaultSub.vaultInfo.totalLpTokenSupply == expectedTotalLpTokenSupply, "ex vaultInvestTotalSupply");

    // Check vault spot balance
    require(vaultSub.spotBalances[investmentCurrency] == expectedVaultSpotBalance, "ex vaultInvestSpotBalance");

    // Check investor's LP state
    _assertVaultLp(vaultSub, investorAssertion, "ex vaultInvestInvestor");
  }

  function assertVaultBurnLpToken(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    VaultLpAssertion calldata lpAssertion
  ) external view {
    SubAccount storage vaultSub = state.subAccounts[vaultID];
    require(vaultSub.isVault, "ex notVault");

    // Check total LP token supply
    require(vaultSub.vaultInfo.totalLpTokenSupply == expectedTotalLpTokenSupply, "ex vaultBurnTotalSupply");

    // Check LP state
    _assertVaultLp(vaultSub, lpAssertion, "ex vaultBurn");
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
    require(vaultSub.isVault, "ex notVault");

    // Check total LP token supply
    require(vaultSub.vaultInfo.totalLpTokenSupply == expectedTotalLpTokenSupply, "ex vaultRedeemTotalSupply");

    // Check vault spot balance
    require(vaultSub.spotBalances[currencyRedeemed] == expectedVaultSpotBalance, "ex vaultRedeemVaultSpotBalance");

    // Check all LP states
    _assertVaultLp(vaultSub, redeemingLpAssertion, "ex vaultRedeemRedeeming");
    _assertVaultLp(vaultSub, managerAssertion, "ex vaultRedeemManager");

    if (feeAccountAssertion.accountID != address(0)) {
      _assertVaultLp(vaultSub, feeAccountAssertion, "ex vaultRedeemFeeAccount");
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
    require(vaultSub.isVault, "ex notVault");

    // Check last fee settlement timestamp
    require(vaultSub.vaultInfo.lastFeeSettlementTimestamp == expectedLastFeeSettlementTimestamp, "ex vaultFeeTick");

    // Check total LP token supply
    require(vaultSub.vaultInfo.totalLpTokenSupply == expectedTotalLpTokenSupply, "ex vaultFeeTickTotalSupply");

    // Check LP states
    _assertVaultLp(vaultSub, managerAssertion, "ex vaultFeeTickManager");

    if (feeAccountAssertion.accountID != address(0)) {
      _assertVaultLp(vaultSub, feeAccountAssertion, "ex vaultFeeTickFeeAccount");
    }
  }
}
