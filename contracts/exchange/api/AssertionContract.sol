// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./RiskCheck.sol";
import "../types/PositionMap.sol";
import "../types/DataStructure.sol";
import "./ConfigContract.sol";

contract AssertionContract is ConfigContract, RiskCheck {
  using BIMath for BI;

  // Assertions for Account Contract
  function assertCreateAccount(address accountID) external view {
    Account storage account = state.accounts[accountID];
    require(
      account.id != address(0) &&
        account.multiSigThreshold == 1 &&
        account.adminCount == 1 &&
        account.subAccounts.length == 0,
      "ex createAcc"
    );
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

  function assertSetConfig(ConfigID key, bytes32 subKey, bytes32 expectedValue) external view {
    ConfigSetting storage setting = state.configSettings[key];
    require(setting.schedules[subKey].lockEndTime == 0, "ex scheduleNotDeleted");

    bool is2DConfig = uint256(setting.typ) % 2 == 0;
    ConfigValue storage config = is2DConfig ? state.config2DValues[key][subKey] : state.config1DValues[key];
    require(config.isSet, "ex configNotSet");
    require(config.val == expectedValue, "ex configValueMismatch");
  }

  // Assertions for Transfer Contract
  function assertDeposit(address accountID, Currency currency, int64 expectedBalance) external view {
    Account storage account = state.accounts[accountID];
    require(account.spotBalances[currency] == expectedBalance, "ex depositBalance");
  }

  function assertWithdraw(
    address fromAccID,
    Currency currency,
    int64 expectedBalance,
    uint64 feeSubAccId,
    int64 expectedFeeBalance
  ) external view {
    Account storage account = state.accounts[fromAccID];
    require(account.spotBalances[currency] == expectedBalance, "ex withdrawBalance");
    SubAccount storage feeSubAcc = state.subAccounts[feeSubAccId];
    require(feeSubAcc.spotBalances[currency] == expectedFeeBalance, "ex feeBalance");
  }

  function assertTransfer(
    address fromAccID,
    address toAccID,
    uint64 fromSubID,
    uint64 toSubID,
    int64 expectedFromBalance,
    int64 expectedToBalance,
    Currency currency
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
  struct SubAccountTradeAssertion {
    uint64 subAccountID;
    int64 fundingTimestamp;
    PositionAssertion[] positions;
    SpotAssertion[] spots;
  }
  struct TradeAssertion {
    SubAccountTradeAssertion[] subAccounts;
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view {
    // ex stands for expectation
    SubAccountTradeAssertion[] calldata exSubs = tradeAssertion.subAccounts;

    for (uint i; i < exSubs.length; ++i) {
      SubAccountTradeAssertion calldata exSub = exSubs[i];
      SubAccount storage sub = state.subAccounts[exSub.subAccountID];

      // Assert funding timestamp
      require(sub.lastAppliedFundingTimestamp == exSub.fundingTimestamp, "exTrade - fundingTimeMismatch");

      // Assert positions
      for (uint j; j < exSub.positions.length; ++j) {
        PositionAssertion calldata exPos = exSub.positions[j];
        PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(exPos.assetID));
        Position storage pos = posmap.values[exPos.assetID];
        require(
          pos.balance == exPos.balance && pos.lastAppliedFundingIndex == exPos.fundingIndex,
          "exTrade - positionMismatch"
        );
      }

      // Assert spot balances
      for (uint j; j < exSub.spots.length; ++j) {
        SpotAssertion calldata exSpot = exSub.spots[j];
        require(sub.spotBalances[exSpot.currency] == exSpot.balance, "exTrade - spotMismatch");
      }
    }
  }

  // Assertions for WalletRecovery Contract
  function assertAddRecoveryAddress(address accountID, address signer, address recoveryAddress) external view {
    Account storage account = state.accounts[accountID];
    require(addressExists(account.recoveryAddresses[signer], recoveryAddress), "ex recoveryAddrNotAdded");
  }

  function assertRemoveRecoveryAddress(address accountID, address signer, address recoveryAddress) external view {
    Account storage account = state.accounts[accountID];
    require(!addressExists(account.recoveryAddresses[signer], recoveryAddress), "ex recoveryAddrNotRemoved");
  }

  function assertRecoverAddress(address accountID, address oldSigner, address newSigner) external view {
    Account storage account = state.accounts[accountID];

    require(account.signers[oldSigner] == 0, "ex oldSignerNotRemoved");
    require(account.signers[newSigner] != 0, "ex newSignerNotAdded");

    require(account.recoveryAddresses[oldSigner].length == 0, "ex oldRecoveryNotCleared");
    require(account.recoveryAddresses[newSigner].length > 0, "ex newRecoveryNotSet");

    for (uint i; i < account.subAccounts.length; ++i) {
      uint64 subAccountID = account.subAccounts[i];
      mapping(address => uint64) storage signers = state.subAccounts[subAccountID].signers;
      require(signers[oldSigner] == 0, "ex oldSubSignerNotRemoved");
      require(signers[newSigner] != 0, "ex newSubSignerNotAdded");
    }
  }

  struct MarginTierAssertion {
    uint64 bracketStart;
    uint32 rate;
  }

  // Assertions for MarginConfig Contract
  function assertSetSimpleCrossMMTiers(bytes32 kud, MarginTierAssertion[] calldata expectedTiers) external view {
    ListMarginTiersBI storage tiers = state.simpleCrossMaintenanceMarginTiers[kud];
    require(tiers.tiers.length == expectedTiers.length, "ex setSimpleCrossMMLenMismatch");

    for (uint i; i < tiers.tiers.length; ++i) {
      MarginTierAssertion calldata exTier = expectedTiers[i];
      MarginTierBI storage tier = tiers.tiers[i];

      // Compare bracketStart
      BI storage bracketStart = tier.bracketStart;
      uint decimals = _getBalanceDecimal(assetGetUnderlying(kud));
      require(bracketStart.toUint64(decimals) == exTier.bracketStart, "ex setSimpleCrossMMTierBracket");

      // Compare rate
      BI storage rate = tier.rate;
      require(rate.toUint64(CENTIBEEP_DECIMALS) == uint64(exTier.rate), "ex setSimpleCrossMMTierRate");
    }
  }

  function assertScheduleSimpleCrossMMTiers(bytes32 kud, int64 expectedLockEndTime) external view {
    require(
      state.simpleCrossMaintenanceMarginTimelockEndTime[kud] == expectedLockEndTime,
      "ex schedSimpleCrossMMTiers"
    );
  }
}
