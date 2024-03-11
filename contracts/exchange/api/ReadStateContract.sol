// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "./BaseContract.sol";

contract ReadStateContract is BaseContract {
  struct AccountResult {
    address id;
    uint64 multiSigThreshold;
    uint64 adminCount;
    uint64[] subAccounts;
    // Not returned fields since mapping is not supported in return type include:
    // 1. spotBalances
    // 2. recoveryAddresses
    // 3. onboardedWithdrawalAddresses
    // 4. onboardedTransferAccounts
    // 5. signers
  }

  struct SubAccountResult {
    uint64 id;
    uint64 adminCount;
    uint64 signerCount;
    address accountID;
    MarginType marginType;
    Currency quoteCurrency;
    int64 lastAppliedFundingTimestamp;
    // Not returned fields since mapping or stucts with nested mapping is not supported in return type include:// The total amount of base currency that the sub account possesses
    // 1. spotBalances
    // 2. PositionsMap options;
    // 3. PositionsMap futures;
    // 4. PositionsMap perps;
    // 5. mapping(bytes => uint256) positionIndex;
    // 6. signers;
  }

  function getAccountResult(address _address) public view returns (AccountResult memory) {
    Account storage account = state.accounts[_address];
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

  function getAccountSpotBalance(address _address, Currency currency) public view returns (uint128) {
    Account storage account = state.accounts[_address];
    return account.spotBalances[currency];
  }

  function isRecoveryAddress(address id, address signer, address recoveryAddress) public view returns (uint256) {
    Account storage account = state.accounts[id];
    return account.recoveryAddresses[signer][recoveryAddress];
  }

  function isOnboardedWithdrawalAddress(address id, address withdrawalAddress) public view returns (bool) {
    Account storage account = state.accounts[id];
    return account.onboardedWithdrawalAddresses[withdrawalAddress];
  }

  function getAccountOnboardedTransferAccount(address _address, address transferAccount) public view returns (bool) {
    Account storage account = state.accounts[_address];
    return account.onboardedTransferAccounts[transferAccount];
  }

  function getSignerPermission(address id, address signer) public view returns (uint64) {
    Account storage account = state.accounts[id];
    return account.signers[signer];
  }

  function getSessionKey(address signer) public view returns (address, int64) {
    return (state.sessions[signer].subAccountSigner, state.sessions[signer].expiry);
  }

  function getConfig2D(ConfigID id, bytes32 subKey) public view returns (bytes32) {
    return state.config2DValues[id][subKey].val;
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

  function getSubAccountResult(uint64 _id) public view returns (SubAccountResult memory) {
    SubAccount storage subAccount = state.subAccounts[_id];
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

  function getSubAccountSpotBalance(uint64 _id, Currency currency) public view returns (uint64) {
    SubAccount storage subAccount = state.subAccounts[_id];
    return subAccount.spotBalances[currency];
  }

  function getSubAccSignerPermission(uint64 _id, address signer) public view returns (uint64) {
    SubAccount storage subAccount = state.subAccounts[_id];
    return subAccount.signers[signer];
  }
}
