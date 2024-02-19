// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "./BaseContract.sol";

contract StateGetterContract is BaseContract {
  function getAccount(
    address _address
  )
    public
    view
    returns (address id, uint multisigThreshold, uint64[] memory subAccounts, uint256 adminCount, uint256 signerCount)
  {
    Account storage account = state.accounts[_address];
    return (account.id, account.multiSigThreshold, account.subAccounts, account.adminCount, account.signerCount);
  }

  function getSpotBalances(address id, Currency currency) public view returns (uint128) {
    Account storage account = state.accounts[id];
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

  function getSignerPermission(address id, address signer) public view returns (uint64) {
    Account storage account = state.accounts[id];
    return account.signers[signer];
  }
}
