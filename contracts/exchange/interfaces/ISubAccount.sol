pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface ISubAccount {
  /// @notice Create a subaccount
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param subAccountID The subaccount ID
  /// @param quoteCurrency The quote currency of the subaccount
  /// @param marginType The margin type of the subaccount
  /// @param sig The signature of the acting user
  function createSubAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint64 subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    Signature calldata sig
  ) external;

  /// @notice Add a signer to a subaccount. This signer will be able to
  /// perform actions like Deposit, Withdrawal, Transfer, Trade etc. on the account, depending on the permissions.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subID The subaccount ID
  /// @param signer The signer to add
  /// @param permissions The permissions of the signer as a bitmask
  /// @param sig The signature of the acting user
  function addSubAccountSigner(
    int64 timestamp,
    uint64 txID,
    uint64 subID,
    address signer,
    uint64 permissions,
    Signature calldata sig
  ) external;

  /// @notice Remove a signer from a subaccount
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param signer The signer to remove
  /// @param sig The signature of the acting user
  function removeSubAccountSigner(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    address signer,
    Signature calldata sig
  ) external;

  /// @notice Add a session key to for a signer. This session key will be
  /// allowed to sign trade transactions for a period of time
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param sessionKey The session key to be added
  /// @param keyExpiry The unix timestamp in nanosecond after which this session expires
  /// @param sig The signature of the acting user
  function addSessionKey(
    int64 timestamp,
    uint64 txID,
    address sessionKey,
    int64 keyExpiry,
    Signature calldata sig
  ) external;

  function setDeriskToMaintenanceMarginRatio(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    uint32 deriskToMaintenanceMarginRatio,
    Signature calldata sig
  ) external;

  /// @notice Remove a session key
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param signer The address of the signer
  function removeSessionKey(int64 timestamp, uint64 txID, address signer) external;
}
