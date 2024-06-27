// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/AccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract AccountContract is BaseContract {
  /// @notice Create a new account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The ID the account will be tagged to
  /// @param sig The signature of the acting user
  function createAccount(int64 timestamp, uint64 txID, address accountID, Signature calldata sig) external {
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
    acc.adminCount = 1;
    acc.signers[sig.signer] = AccountPermAdmin;
  }

  /// @notice Set the multiSigThreshold for an account
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param multiSigThreshold The multiSigThreshold that is set
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function setAccountMultiSigThreshold(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(acc.id != address(0), "account does not exist");
    require(multiSigThreshold > 0 && multiSigThreshold <= acc.adminCount, "invalid threshold");

    // ---------- Signature Verification -----------
    bytes32 hash = hashSetMultiSigThreshold(accountID, multiSigThreshold, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.multiSigThreshold = multiSigThreshold;
  }

  /// @notice Add a signer to an account or change the permissions of an existing signer
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param signer The new signer
  /// @param permissions The permissions of the new signer
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function addAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint64 permissions,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(acc.id != address(0), "account does not exist");

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddAccountSigner(accountID, signer, permissions, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    if (curPerm & AccountPermAdmin == 0 && permissions & AccountPermAdmin != 0) {
      acc.adminCount++;
    }

    if (curPerm & AccountPermAdmin != 0 && permissions & AccountPermAdmin == 0) {
      require(acc.adminCount > 1, "require 1 admin");
      require(acc.multiSigThreshold <= acc.adminCount - 1, "require threshold <= adminCount - 1");
      acc.adminCount--;
    }

    acc.signers[signer] = permissions;
  }

  /// @notice Remove a signer from an account
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param signer The signer to be removed
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function removeAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveAccountSigner(accountID, signer, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    bool isAdmin = curPerm & AccountPermAdmin != 0;
    if (isAdmin) {
      require(acc.adminCount > 1, "require 1 admin");
      require(acc.multiSigThreshold <= acc.adminCount - 1, "require threshold <= adminCount - 1");
      acc.adminCount--;
    }
    acc.signers[signer] = 0;
  }

  /// @notice Add withdrawal address that the account can withdraw to
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param withdrawalAddress The withdrawal address
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function addWithdrawalAddress(
    int64 timestamp,
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
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = true;
  }

  /// @notice Remove withdrawal address that the account can withdraw to
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param withdrawalAddress The withdrawal address
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function removeWithdrawalAddress(
    int64 timestamp,
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
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = false;
  }

  /// @notice Add a account that this account can transfer to
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the acting users
  function addTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    require(transferAccountID != address(0), "invalid transfer account");

    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddTransferAccount(accountID, transferAccountID, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End hashAddTransferAccount -------

    acc.onboardedTransferAccounts[transferAccountID] = true;
  }

  function removeTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveTransferAccount(accountID, transferAccountID, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedTransferAccounts[transferAccountID] = false;
  }
}
