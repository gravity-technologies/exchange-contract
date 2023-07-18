// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, Signature, State, SubAccount, Currency, MarginType} from '../DataStructure.sol';
import {checkAndUpdateTimestampAndTxID, getAccountAndSubAccountByID} from '../util/Util.sol';
import {getCreateSubAccountPayloadPacketHash, getAddAccountAdminPayloadPacketHash, getSetAccountMultiSigThresholdPayloadPacketHash, getRemoveAccountAdminPayloadPacketHash, getAddWithdrawalAddressPayloadPacketHash, getRemoveWithdrawalAddressPayloadPacketHash, getAddTransferSubAccountPayloadPacketHash, getRemoveTransferSubAccountPayloadPacketHash} from './signature/AccountSig.sol';
import {verify} from './signature/Common.sol';
import {Signer, SubAccount, Account, State, Signature} from '../DataStructure.sol';
import {addAddress, addressExists, removeAddress} from '../util/Address.sol';
import {checkAndUpdateTimestampAndTxID, getAccountByID} from '../util/Util.sol';
import 'openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';

abstract contract AccountAPI {
  function _getState() internal virtual returns (State storage);

  function CreateSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    uint32 nonce,
    Signature[] memory signatures
  ) external {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    (Account storage acc, SubAccount storage sub) = getAccountAndSubAccountByID(
      state,
      accountID,
      subAccountID
    );
    require(sub.accountID == 0, 'subaccount already exists');

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getCreateSubAccountPayloadPacketHash(
      accountID,
      subAccountID,
      quoteCurrency,
      marginType,
      nonce
    );
    for (uint i = 0; i < signatures.length; i++) {
      Signature memory sig = signatures[i];
      require(
        sig.expiration > 0 && sig.expiration > timestamp,
        'signature expired'
      );
      verify(hash, sig);
    }
    // ------- End of Signature Verification -------

    // Create subaccount
    sub.id = subAccountID;
    sub.accountID = accountID;
    sub.marginType = marginType;
    sub.quoteCurrency = quoteCurrency;
    sub.lastAppliedFundingTimestamp = timestamp;
    // We will not create any authorizedSigners in subAccount upon creation. All account admins are presumably authorizedSigners

    // Create a new account if one did not exist
    if (acc.id == 0) {
      acc.id = accountID;
      acc.multiSigThreshold = 1;
      // the first account admins is the signer of the first signature
      acc.admins.push(signatures[0].signer);
      acc.subAccounts.push(subAccountID);
    }
  }

  function SetAccountMultiSigThreshold(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireQuorum(acc.multiSigThreshold, signatures.length);
    require(
      multiSigThreshold > 0 && multiSigThreshold <= acc.admins.length,
      'multiSigThreshold is invalid'
    );

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getSetAccountMultiSigThresholdPayloadPacketHash(
      accountID,
      multiSigThreshold,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    // TODO: signature verification
    acc.multiSigThreshold = multiSigThreshold;
  }

  function AddAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddAccountAdminPayloadPacketHash(
      accountID,
      signer,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.admins, signer);
  }

  function RemoveAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveAccountAdminPayloadPacketHash(
      accountID,
      signer,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.admins, signer, true);
  }

  function AddWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddWithdrawalAddressPayloadPacketHash(
      accountID,
      withdrawalAddress,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress);
  }

  function RemoveWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveWithdrawalAddressPayloadPacketHash(
      accountID,
      withdrawalAddress,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress, false);
  }

  function AddTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getAddTransferSubAccountPayloadPacketHash(
      accountID,
      transferSubAccount,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.onboardedTransferSubAccounts, transferSubAccount);
  }

  function RemoveTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    uint32 nonce,
    Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);

    Account storage acc = getAccountByID(state, accountID);

    // ------- Signature Verification -------
    requireQuorum(acc.multiSigThreshold, signatures.length);
    bytes32 hash = getRemoveTransferSubAccountPayloadPacketHash(
      accountID,
      transferSubAccount,
      nonce
    );
    verifyAllSignatures(state.timestamp, acc.admins, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.onboardedTransferSubAccounts, transferSubAccount, false);
  }
}

function requireQuorum(uint256 quorum, uint256 numSignatures) pure {
  // If the account is new, the threshold is 0, but we still need at least 1 signature.
  require(numSignatures >= max(quorum, 1), 'insufficient signatures');
}

function max(uint a, uint b) pure returns (uint) {
  return a >= b ? a : b;
}

function verifyAllSignatures(
  uint64 timestamp,
  address[] memory admins,
  bytes32 hash,
  Signature[] memory signatures
) pure {
  for (uint i = 0; i < signatures.length; i++) {
    Signature memory sig = signatures[i];
    require(addressExists(admins, sig.signer), 'signer not an admin');
    require(
      sig.expiration > 0 && sig.expiration > timestamp,
      'signature expired'
    );
    verify(hash, sig);
  }
}
