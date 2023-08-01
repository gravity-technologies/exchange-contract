// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {getAddAccountAdminPayloadPacketHash, getAddTransferSubAccountPayloadPacketHash, getAddWithdrawalAddressPayloadPacketHash, getCreateSubAccountPayloadPacketHash, getRemoveAccountAdminPayloadPacketHash, getRemoveTransferSubAccountPayloadPacketHash, getRemoveWithdrawalAddressPayloadPacketHash, getSetAccountMultiSigThresholdPayloadPacketHash} from './signature/generated/AccountSig.sol';
import {Signer, SubAccount, SignatureState, Account, State, Account, Signature, State, SubAccount, Currency, MarginType} from '../DataStructure.sol';
import {verify} from './signature/Common.sol';
import {addAddress, addressExists, removeAddress} from '../util/Address.sol';
import {checkAndUpdateTimestampAndTxID, getAccountAndSubAccountByID, getAccountByID} from '../util/Util.sol';
import 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

abstract contract AccountContract {
  function _getState() internal virtual returns (State storage);

  function createSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    (Account storage acc, SubAccount storage sub) = getAccountAndSubAccountByID(state, accountID, subAccountID);
    require(sub.accountID == 0, 'subaccount already exists');

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getCreateSubAccountPayloadPacketHash(accountID, subAccountID, quoteCurrency, marginType, nonce);
    if (acc.id == 0) {
      for (uint i = 0; i < signatures.length; i++) {
        verify(state.signatures.isExecuted, timestamp, hash, signatures[i]);
      }
    } else {
      _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
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
      acc.admins.push(signatures[0].signer);
      acc.subAccounts.push(subAccountID);
    }
  }

  function setAccountMultiSigThreshold(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    require(multiSigThreshold > 0 && multiSigThreshold <= acc.admins.length, 'multiSigThreshold is invalid');

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getSetAccountMultiSigThresholdPayloadPacketHash(accountID, multiSigThreshold, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    acc.multiSigThreshold = multiSigThreshold;
  }

  function addAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddAccountAdminPayloadPacketHash(accountID, signer, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.admins, signer);
  }

  function removeAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveAccountAdminPayloadPacketHash(accountID, signer, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.admins, signer, true);
  }

  function addWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddWithdrawalAddressPayloadPacketHash(accountID, withdrawalAddress, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress);
  }

  function removeWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveWithdrawalAddressPayloadPacketHash(accountID, withdrawalAddress, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress, false);
  }

  function addTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddTransferSubAccountPayloadPacketHash(accountID, transferSubAccount, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedTransferSubAccounts, transferSubAccount);
  }

  function removeTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ---------- Signature Verification -----------
    _requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveTransferSubAccountPayloadPacketHash(accountID, transferSubAccount, nonce);
    _requiresAllAdminSignatures(state.signatures.isExecuted, timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedTransferSubAccounts, transferSubAccount, false);
  }
}

function _requireQuorum(uint256 quorum, uint256 numSignatures) pure {
  // If the account is new, the threshold is 0, but we still need at least 1 signature.
  require(numSignatures >= _max(quorum, 1), 'insufficient signatures');
}

function _max(uint a, uint b) pure returns (uint) {
  return a >= b ? a : b;
}

function _requiresAllAdminSignatures(
  mapping(bytes32 => bool) storage isExecuted,
  uint64 timestamp,
  address[] memory admins,
  bytes32 hash,
  Signature[] calldata signatures
) {
  for (uint i = 0; i < signatures.length; i++) {
    Signature calldata sig = signatures[i];
    require(addressExists(admins, sig.signer), 'signer not an admin');
    verify(isExecuted, timestamp, hash, sig);
  }
}
