// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {HelperContract} from "./HelperContract.sol";
import {getDepositPayloadPacketHash, getWithdrawalPayloadPacketHash, getTransferPayloadPacketHash} from "./signature/generated/TransferSig.sol";
import {requireValidSig} from "./signature/Common.sol";
import {Account, MarginType, SessionKey, Signature, Signer, State, SubAccount, SubAccountPermAddSigner, SubAccountPermAdmin, SubAccountPermChangeMarginType, SubAccountPermRemoveSignerPermission, SubAccountPermTrade, SubAccountPermUpdateSigner} from "../DataStructure.sol";
import {addressExists} from "../util/Address.sol";

abstract contract TransferContract is HelperContract {
  function _getState() internal virtual returns (State storage);

  // function deposit(
  //   uint64 timestamp,
  //   uint64 txID,
  //   address fromEthAddress,
  //   address toSubAccount,
  //   uint64 numTokens,
  //   Signature calldata sig
  // ) external {
  //   State storage state = _getState();
  //   _setTimestampAndTxID(state, timestamp, txID);
  //   SubAccount storage sub = _requireSubAccount(state, toSubAccount);
  //   // Account storage acc = _requireAccount(state, toSubAccount.accountID);

  //   // Signature must be from grvt
  //   require(sig.signer == address(0), "grvt must sign");

  //   // ---------- Signature Verification -----------
  //   // bytes32 hash = getAddSessionKeyPayloadPacketHash(toSubAccount, sessionKey, expiry, nonce);
  //   // requireValidSig(state.signatures.isExecuted, timestamp, hash, sig);
  //   // ------- End of Signature Verification -------

  //   sub.balance += int64(numTokens);
  // }

  // function withdrawal(
  //   uint64 timestamp,
  //   uint64 txID,
  //   address fromSubAccount,
  //   address toEthAddress,
  //   uint64 numTokens,
  //   Signature calldata sig
  // ) external {
  //   State storage state = _getState();
  //   _setTimestampAndTxID(state, timestamp, txID);
  //   SubAccount storage sub = _requireSubAccount(state, fromSubAccount);
  //   Account storage acc = _requireAccount(state, sub.accountID);

  //   // Signature must be from grvt
  //   require(sig.signer == address(0), "grvt must sign");

  //   // ---------- Signature Verification -----------
  //   // bytes32 hash = getAddSessionKeyPayloadPacketHash(fromSubAccount, sessionKey, expiry, nonce);
  //   // requireValidSig(state.signatures.isExecuted, timestamp, hash, sig);
  //   // ------- End of Signature Verification -------

  //   // 1. requireValidSig the account has enough maintenance balance after withdrawal
  //   // Run span simulation

  //   // 2. Call the bridging contract

  //   // 3. Update balance
  //   sub.balance -= int64(numTokens);
  // }

  // function transfer(
  //   uint64 timestamp,
  //   uint64 txID,
  //   address fromSubAccount,
  //   address toSubAccount,
  //   uint64 numTokens,
  //   Signature calldata sig
  // ) external {
  //   State storage state = _getState();
  //   _setTimestampAndTxID(state, timestamp, txID);
  //   SubAccount storage fromSub = _requireSubAccount(state, fromSubAccount);
  //   // SubAccount storage toSub = _requireSubAccount(state, toSub);

  //   // require(fromSub.accountID == toSub.accountID, "different account");
  //   // require(fromSub.quoteCurrency == toSub.quoteCurrency, "different currency");
  //   // require(fromSub.balance >= numTokens, "insufficient balance");

  //   // Account storage acc = _requireAccount(state, sub.accountID);

  //   // // ---------- Signature Verification -----------
  //   // bytes32 hash = getAddSessionKeyPayloadPacketHash(fromSubAccount, sessionKey, expiry, nonce);
  //   // requireValidSig(state.signatures.isExecuted, timestamp, hash, sig);
  //   // ------- End of Signature Verification -------
  // }
}
