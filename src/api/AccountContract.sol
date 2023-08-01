// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "./signature/generated/AccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract AccountContract is HelperContract {
  function createSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = state.accounts[accountID];
    SubAccount storage sub = state.subAccounts[subAccountID];
    require(sub.accountID == 0, "subaccount already exists");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateSubAccount(accountID, subAccountID, quoteCurrency, marginType, nonce);
    if (acc.id == 0) {
      require(sigs.length > 0, "no signature");
      for (uint i = 0; i < sigs.length; i++) {
        _preventReplay(hash, sigs[i]);
      }
    } else {
      _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    }
    // ------- End of Signature Verification -------

    // Create subaccount
    sub.id = subAccountID;
    sub.accountID = accountID;
    sub.marginType = marginType;
    sub.quoteCurrency = quoteCurrency;
    sub.lastAppliedFundingTimestamp = timestamp;
    // We will not create any authorizedSigners in subAccount upon creation.
    // All account admins are presumably authorizedSigners

    // Create a new account if one did not exist
    if (acc.id == 0) {
      acc.id = accountID;
      acc.multiSigThreshold = 1;
      // the first account admins is the signer of the first signature
      acc.admins.push(sigs[0].signer);
      acc.subAccounts.push(subAccountID);
    }
  }

  function setAccountMultiSigThreshold(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(multiSigThreshold > 0 && multiSigThreshold <= acc.admins.length, "invalid threshold");

    // ---------- Signature Verification -----------
    bytes32 hash = hashSetMultiSigThreshold(accountID, multiSigThreshold, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.multiSigThreshold = multiSigThreshold;
  }

  function addAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddAccountAdmin(accountID, signer, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    addAddress(acc.admins, signer);
  }

  function removeAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveAccountAdmin(accountID, signer, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    removeAddress(acc.admins, signer, true);
  }

  function addWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddWithdrawalAddress(accountID, withdrawalAddress, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress);
  }

  function removeWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveWithdrawalAddress(accountID, withdrawalAddress, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    // TODO: check if we need to maintain at least 1 withdrawal address
    removeAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress, false);
  }

  function addTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddTransferSubAccount(accountID, transferSubAccount, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedTransferSubAccounts, transferSubAccount);
  }

  function removeTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accID,
    address subAcc,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveTransferSubAccount(accID, subAcc, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedTransferSubAccounts, subAcc, false);
  }
}
