pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IWalletRecovery {
  /// @notice Add a recovery address for a signer for a given signer for a given account
  /// The recoveryAddress can be used to change the signer from the signer to another signer from the account and subAccounts associated with the account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param recoveryAddress The recovery address that can be used to change the signer
  /// @param sig The signature of the signer for which the recovery address is being added
  function addRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address recoveryAddress,
    Signature calldata sig
  ) external;

  /// @notice Remove a recovery address for a signer for a given signer for a given account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param recoveryAddress The recovery address that is being removed
  /// @param sig The signature of the signer whose recovery address is being removed
  function removeRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address recoveryAddress,
    Signature calldata sig
  ) external;

  /// @notice Recover the address of an account
  /// Replaces the oldSigner with the newSigner with the newSigner having the same permissions
  /// as the oldSigner in the account and all the subAccounts associated with the account.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param oldSigner  existing signer that can have permissions in the account but needs to be replaced
  /// @param newSigner new signer that will replace the oldSigner
  /// @param recoverySignerSig The signature of the recoverySigner
  function recoverAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address oldSigner,
    address newSigner,
    Signature calldata recoverySignerSig
  ) external;
}
