// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./RiskCheck.sol";
import "../types/PositionMap.sol";
import "./ConfigContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

struct SpotBalanceAssertion {
  Currency currency;
  int64 balance;
}

struct RecoveryAddressAssertion {
  address signer;
  address[] recoveryAddresses;
}

struct SignerAssertion {
  address signer;
  uint64 permission;
}

struct AccountAssertion {
  address id;
  uint64 multiSigThreshold;
  uint64 adminCount;
  uint64[] subAccounts;
  SpotBalanceAssertion[] spotBalances;
  RecoveryAddressAssertion[] recoveryAddresses;
  address[] onboardedWithdrawalAddresses;
  address[] onboardedTransferAccounts;
  SignerAssertion[] signers;
}

struct SubAccountAssertion {
  uint64 id;
  uint64 adminCount;
  uint64 signerCount;
  address accountID;
  MarginType marginType;
  Currency quoteCurrency;
  int64 lastAppliedFundingTimestamp;
  SpotBalanceAssertion[] spotBalances;
  Position[] options;
  Position[] futures;
  Position[] perps;
  SignerAssertion[] signers;
}

contract AssertionContract is ConfigContract, RiskCheck {
  using BIMath for BI;
  using Strings for uint64;

  function assertIsAllAccountExists(address[] calldata accountIDs, bool expected) public view {
    bool result = isAllAccountExists(accountIDs);
    require(result == expected, "AssertionContract: isAllAccountExists assertion failed");
  }

  function assertAccountSpotBalance(address accID, Currency currency, int64 expected) public view {
    int64 balance = getAccountSpotBalance(accID, currency);
    require(balance == expected, "AssertionContract: accountSpotBalance assertion failed");
  }

  function assertIsRecoveryAddress(address id, address signer, address recoveryAddress, bool expected) public view {
    bool result = isRecoveryAddress(id, signer, recoveryAddress);
    require(result == expected, "AssertionContract: isRecoveryAddress assertion failed");
  }

  function assertIsOnboardedWithdrawalAddress(address id, address withdrawalAddress, bool expected) public view {
    bool result = isOnboardedWithdrawalAddress(id, withdrawalAddress);
    require(result == expected, "AssertionContract: isOnboardedWithdrawalAddress assertion failed");
  }

  function assertAccountOnboardedTransferAccount(address accID, address transferAccount, bool expected) public view {
    bool result = getAccountOnboardedTransferAccount(accID, transferAccount);
    require(result == expected, "AssertionContract: accountOnboardedTransferAccount assertion failed");
  }

  function assertSignerPermission(address id, address signer, uint64 expected) public view {
    uint64 permission = getSignerPermission(id, signer);
    require(permission == expected, "AssertionContract: signerPermission assertion failed");
  }

  function assertSessionValue(address sessionKey, address expectedSigner, int64 expectedExpiry) public view {
    (address signer, int64 expiry) = getSessionValue(sessionKey);
    require(signer == expectedSigner && expiry == expectedExpiry, "AssertionContract: sessionValue assertion failed");
  }

  function assertConfig2D(ConfigID id, bytes32 subKey, bytes32 expected) public view {
    bytes32 result = getConfig2D(id, subKey);
    require(result == expected, "AssertionContract: config2D assertion failed");
  }

  function assertConfig1DIsSet(ConfigID id, bool expected) public view {
    bool result = config1DIsSet(id);
    require(result == expected, "AssertionContract: config1DIsSet assertion failed");
  }

  function assertConfig2DIsSet(ConfigID id, bool expected) public view {
    bool result = config2DIsSet(id);
    require(result == expected, "AssertionContract: config2DIsSet assertion failed");
  }

  function assertConfig1D(ConfigID id, bytes32 expected) public view {
    bytes32 result = getConfig1D(id);
    require(result == expected, "AssertionContract: config1D assertion failed");
  }

  function assertConfigSchedule(ConfigID id, bytes32 subKey, int64 expected) public view {
    int64 result = getConfigSchedule(id, subKey);
    require(result == expected, "AssertionContract: configSchedule assertion failed");
  }

  function assertIsConfigScheduleAbsent(ConfigID id, bytes32 subKey, bool expected) public view {
    bool result = isConfigScheduleAbsent(id, subKey);
    require(result == expected, "AssertionContract: isConfigScheduleAbsent assertion failed");
  }

  function assertSubAccSignerPermission(uint64 id, address signer, uint64 expected) public view {
    uint64 permission = getSubAccSignerPermission(id, signer);
    require(permission == expected, "AssertionContract: subAccSignerPermission assertion failed");
  }

  function assertFundingIndex(bytes32 assetID, int64 expected) public view {
    int64 index = getFundingIndex(assetID);
    require(index == expected, "AssertionContract: fundingIndex assertion failed");
  }

  function assertFundingTime(int64 expected) public view {
    int64 time = getFundingTime();
    require(time == expected, "AssertionContract: fundingTime assertion failed");
  }

  function assertMarkPrice(bytes32 assetID, uint64 expectedPrice, bool expectedIsSet) public view {
    (uint64 price, bool isSet) = getMarkPrice(assetID);
    require(price == expectedPrice && isSet == expectedIsSet, "AssertionContract: markPrice assertion failed");
  }

  function assertSettlementPrice(bytes32 assetID, uint64 expectedValue, bool expectedIsSet) public view {
    (uint64 value, bool isSet) = getSettlementPrice(assetID);
    require(value == expectedValue && isSet == expectedIsSet, "AssertionContract: settlementPrice assertion failed");
  }

  function assertInterestRate(bytes32 assetID, int32 expected) public view {
    int32 rate = getInterestRate(assetID);
    require(rate == expected, "AssertionContract: interestRate assertion failed");
  }

  function assertSubAccountValue(uint64 subAccountID, int64 expected) public view {
    int64 value = getSubAccountValue(subAccountID);
    require(
      value == expected,
      string(
        abi.encodePacked(
          "AssertionContract: subAccountValue mismatch. ",
          "SubAccountID: ",
          subAccountID.toString(),
          ", ",
          "Expected: ",
          _int64ToString(expected),
          ", ",
          "Actual: ",
          _int64ToString(value)
        )
      )
    );
  }

  function assertSubAccountPosition(
    uint64 subAccountID,
    bytes32 assetID,
    bool expectedFound,
    int64 expectedBalance,
    int64 expectedLastAppliedFundingIndex
  ) public view {
    (bool found, int64 balance, int64 lastAppliedFundingIndex) = getSubAccountPosition(subAccountID, assetID);

    require(
      found == expectedFound,
      string(
        abi.encodePacked(
          "AssertionContract: subAccountPosition 'found' mismatch. ",
          "SubAccountID: ",
          subAccountID.toString(),
          ", ",
          "AssetID: ",
          bytes32ToString(assetID),
          ", ",
          "Expected: ",
          expectedFound ? "true" : "false",
          ", Actual: ",
          found ? "true" : "false"
        )
      )
    );

    require(
      balance == expectedBalance,
      string(
        abi.encodePacked(
          "AssertionContract: subAccountPosition 'balance' mismatch. ",
          "SubAccountID: ",
          subAccountID.toString(),
          ", ",
          "AssetID: ",
          bytes32ToString(assetID),
          ", ",
          "Expected: ",
          _int64ToString(expectedBalance),
          ", Actual: ",
          _int64ToString(balance)
        )
      )
    );

    require(
      lastAppliedFundingIndex == expectedLastAppliedFundingIndex,
      string(
        abi.encodePacked(
          "AssertionContract: subAccountPosition 'lastAppliedFundingIndex' mismatch. ",
          "SubAccountID: ",
          subAccountID.toString(),
          ", ",
          "AssetID: ",
          bytes32ToString(assetID),
          ", ",
          "Expected: ",
          _int64ToString(expectedLastAppliedFundingIndex),
          ", Actual: ",
          _int64ToString(lastAppliedFundingIndex)
        )
      )
    );
  }

  function _int64ToString(int64 value) internal pure returns (string memory) {
    return
      value >= 0
        ? string(abi.encodePacked("+", uint64(value).toString()))
        : string(abi.encodePacked("-", uint64(-value).toString()));
  }

  function assertSubAccountSpotBalance(uint64 subAccountID, Currency currency, int64 expected) public view {
    int64 balance = getSubAccountSpotBalance(subAccountID, currency);
    require(balance == expected, "AssertionContract: subAccountSpotBalance assertion failed");
  }

  function assertAccount(AccountAssertion calldata assertion) public view {
    Account storage account = state.accounts[assertion.id];

    require(assertion.id != address(0), "id == 0 in account assertion");
    require(account.id != address(0), "account not found");
    require(account.id == assertion.id, "UnexpectedAccount ID");
    require(account.multiSigThreshold == assertion.multiSigThreshold, "MultiSigThreshold mismatch");
    require(account.adminCount == assertion.adminCount, "AdminCount mismatch");
    require(
      keccak256(abi.encodePacked(account.subAccounts)) == keccak256(abi.encodePacked(assertion.subAccounts)),
      "SubAccounts mismatch"
    );

    for (uint i = 0; i < assertion.spotBalances.length; i++) {
      require(
        account.spotBalances[assertion.spotBalances[i].currency] == assertion.spotBalances[i].balance,
        "SpotBalance mismatch"
      );
    }

    for (uint i = 0; i < assertion.recoveryAddresses.length; i++) {
      address[] storage recoveryAddresses = account.recoveryAddresses[assertion.recoveryAddresses[i].signer];
      require(
        keccak256(abi.encodePacked(recoveryAddresses)) ==
          keccak256(abi.encodePacked(assertion.recoveryAddresses[i].recoveryAddresses)),
        "RecoveryAddresses mismatch"
      );
    }

    for (uint i = 0; i < assertion.onboardedWithdrawalAddresses.length; i++) {
      require(
        account.onboardedWithdrawalAddresses[assertion.onboardedWithdrawalAddresses[i]],
        "OnboardedWithdrawalAddress mismatch"
      );
    }

    for (uint i = 0; i < assertion.onboardedTransferAccounts.length; i++) {
      require(
        account.onboardedTransferAccounts[assertion.onboardedTransferAccounts[i]],
        "OnboardedTransferAccount mismatch"
      );
    }

    for (uint i = 0; i < assertion.signers.length; i++) {
      require(
        account.signers[assertion.signers[i].signer] == assertion.signers[i].permission,
        "Signer permission mismatch"
      );
    }
  }

  function assertSubAccount(SubAccountAssertion calldata assertion, bool requireFullPositionMap) public view {
    SubAccount storage subAccount = state.subAccounts[assertion.id];

    require(assertion.id != 0, "id == 0 in SubAccount assertion");
    require(subAccount.id != 0, "SubAccount not found");
    require(subAccount.id == assertion.id, "Unexpected SubAccount ID");
    require(subAccount.adminCount == assertion.adminCount, "AdminCount mismatch");
    require(subAccount.signerCount == assertion.signerCount, "SignerCount mismatch");
    require(subAccount.accountID == assertion.accountID, "AccountID mismatch");
    require(subAccount.marginType == assertion.marginType, "MarginType mismatch");
    require(subAccount.quoteCurrency == assertion.quoteCurrency, "QuoteCurrency mismatch");
    require(
      subAccount.lastAppliedFundingTimestamp == assertion.lastAppliedFundingTimestamp,
      "LastAppliedFundingTimestamp mismatch"
    );

    for (uint i = 0; i < assertion.spotBalances.length; i++) {
      require(
        subAccount.spotBalances[assertion.spotBalances[i].currency] == assertion.spotBalances[i].balance,
        "SpotBalance mismatch"
      );
    }

    assertPositionsMap(subAccount.options, assertion.options, "Options", requireFullPositionMap);
    assertPositionsMap(subAccount.futures, assertion.futures, "Futures", requireFullPositionMap);
    assertPositionsMap(subAccount.perps, assertion.perps, "Perps", requireFullPositionMap);

    for (uint i = 0; i < assertion.signers.length; i++) {
      require(
        subAccount.signers[assertion.signers[i].signer] == assertion.signers[i].permission,
        "Signer permission mismatch"
      );
    }
  }

  function assertPositionsMap(
    PositionsMap storage posMap,
    Position[] memory assertion,
    string memory mapName,
    bool requireFullPositionMap
  ) internal view {
    if (requireFullPositionMap) {
      require(
        posMap.keys.length == assertion.length,
        string(abi.encodePacked(mapName, " PositionsMap length mismatch"))
      );
    }

    for (uint i = 0; i < assertion.length; i++) {
      Position storage pos = posMap.values[assertion[i].id];
      require(pos.balance == assertion[i].balance, string(abi.encodePacked(mapName, " Position balance mismatch")));
      require(
        pos.lastAppliedFundingIndex == assertion[i].lastAppliedFundingIndex,
        string(abi.encodePacked(mapName, " Position lastAppliedFundingIndex mismatch"))
      );
    }
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
    return _getMarkPrice9Decimals(assetID);
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
    return _getSubAccountUsdValue(sub).toInt64(quoteDecimals);
  }

  function getSubAccountPosition(
    uint64 subAccountID,
    bytes32 assetID
  ) public view returns (bool found, int64 balance, int64 lastAppliedFundingIndex) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(assetID));
    Position storage pos = posmap.values[assetID];
    return (pos.id != 0x0, pos.balance, pos.lastAppliedFundingIndex);
  }

  function getSubAccountSpotBalance(uint64 subAccountID, Currency currency) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.spotBalances[currency];
  }
}
