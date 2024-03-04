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
    // mapping(Currency => uint128) spotBalances;
    // mapping(address => mapping(address => uint256)) recoveryAddresses;
    // mapping(address => bool) onboardedWithdrawalAddresses;
    // mapping(address => bool) onboardedTransferAccounts;
    // mapping(address => uint64) signers;
  }

  function getAccountResult(address _address) public view returns (AccountResult memory) {
    Account storage account = state.accounts[_address];
    return
      AccountResult({
        id: account.id,
        multiSigThreshold: account.multiSigThreshold,
        adminCount: account.adminCount,
        subAccounts: account.subAccounts
        // Not returned fields since mapping is not supported in return type include:
        // 1. spotBalances
        // 2. recoveryAddresses
        // 3. onboardedWithdrawalAddresses
        // 4. onboardedTransferAccounts
        // 5. signers
      });
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

  function getAccount(
    address _address
  ) public view returns (address id, uint multisigThreshold, uint64[] memory subAccounts, uint256 adminCount) {
    Account storage account = state.accounts[_address];
    return (account.id, account.multiSigThreshold, account.subAccounts, account.adminCount);
  }
}
