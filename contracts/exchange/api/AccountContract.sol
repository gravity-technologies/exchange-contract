// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HelperContract.sol";
import "./signature/generated/AccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract AccountContract is HelperContract {
  function createAccount(uint64 timestamp, uint64 txID, address accountID, Signature calldata sig) external {
    _setSequence(timestamp, txID);
    Account storage acc = state.accounts[accountID];
    require(acc.id == address(0), "account already exists");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateAccount(accountID, sig.nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    // Create account
    acc.id = accountID;
    acc.multiSigThreshold = 1;
    acc.admins.push(sig.signer);
  }

  function setAccountMultiSigThreshold(
    uint64 timestamp,
    uint64 txID,
    address accountID,
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
    address accountID,
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
    address accountID,
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
    address accountID,
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
    address accountID,
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
    address accountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddTransferAccount(accountID, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End hashAddTransferAccount -------

    addAddress(acc.onboardedTransferAccounts, accountID);
  }

  function removeTransferAccount(
    uint64 timestamp,
    uint64 txID,
    address accID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveTransferAccount(accID, nonce);
    _requireSignatureQuorum(acc.admins, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedTransferAccounts, accID, false);
  }
}
