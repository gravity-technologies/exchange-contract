pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IAccount {
  /// @notice Create a new account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The ID the account will be tagged to
  /// @param sig The signature of the acting user
  function createAccount(int64 timestamp, uint64 txID, address accountID, Signature calldata sig) external;

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
  ) external;

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
  ) external;

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
  ) external;

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
  ) external;

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
  ) external;

  /// @notice Add a account that this account can transfer to
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param transferAccountID The account ID to transfer to
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the acting users
  function addTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external;

  /// @notice Remove a account that this account can transfer to
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param transferAccountID The account ID to remove
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the acting users
  function removeTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external;

  /// @notice Create a new account and subaccount in a single transaction
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The ID the account will be tagged to
  /// @param subAccountID The subaccount ID
  /// @param quoteCurrency The quote currency of the subaccount
  /// @param marginType The margin type of the subaccount
  /// @param sig The signature of the acting user
  function createAccountWithSubAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    Currency quoteCurrency,
    Signature calldata sig
  ) external;
}
