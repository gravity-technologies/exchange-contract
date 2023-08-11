// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./OracleContract.sol";
import "./PositionValueContract.sol";
import "./signature/generated/TransferSig.sol";
import "../DataStructure.sol";
import "../util/Address.sol";

abstract contract TransferContract is PositionValueContract {
  /// @notice Deposit collateral into a sub account
  ///
  /// @param timestamp Timestamp of the transaction
  /// @param txID Transaction ID
  /// @param ethAddress Ethereum address of the depositor
  /// @param toSubID Sub account to deposit into
  /// @param numTokens Number of tokens to deposit
  /// @param nonce Nonce of the transaction
  /// @param sig Signature of the transaction
  function deposit(
    uint64 timestamp,
    uint64 txID,
    address ethAddress,
    address toSubID,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(toSubID);
    // Account storage acc = _requireAccount( toSubAccount.accountID);

    // Signature must be from grvt
    require(sig.signer == address(0), "grvt must sign");

    // ---------- Signature Verification -----------
    bytes32 hash = hashDeposit(ethAddress, toSubID, numTokens, nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    sub.balance += int64(numTokens);
  }

  /// @notice Withdraw collateral from a sub account
  ///
  /// @param timestamp Timestamp of the transaction
  /// @param txID Transaction ID
  /// @param fromSubID Sub account to withdraw from
  /// @param toEthAddress Ethereum address of the withdrawer
  /// @param numTokens Number of tokens to withdraw
  /// @param nonce Nonce of the transaction
  /// @param sig Signature of the transaction
  function withdrawal(
    uint64 timestamp,
    uint64 txID,
    address fromSubID,
    address toEthAddress,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(fromSubID);

    // Signature must be from grvt
    require(sig.signer == address(0), "grvt must sign");

    // ---------- Signature Verification -----------
    bytes32 hash = hashWithdrawal(fromSubID, toEthAddress, numTokens, nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    // 1. Ensure that the user can only withdraw up to the total value of the subaccount
    int256 totalVal = _getTotalValue(sub);
    require(int64(numTokens) <= totalVal, "withdrawal amount exceeds total value");

    // 2. Call the bridging contract

    // 3. Update balance
    sub.balance -= int64(numTokens);
  }

  /// @notice Transfer tokens from one sub account to another sub account
  ///
  /// @param timestamp Timestamp of the transaction
  /// @param txID Transaction ID
  /// @param fromSubAcc Sub account to transfer from
  /// @param toSubAcc Sub account to transfer to
  /// @param numTokens Number of tokens to transfer
  /// @param nonce Nonce of the transaction
  /// @param sig Signature of the transaction
  function transfer(
    uint64 timestamp,
    uint64 txID,
    address fromSubAcc,
    address toSubAcc,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage fromSub = _requireSubAccount(fromSubAcc);
    SubAccount storage toSub = _requireSubAccount(toSubAcc);

    require(fromSub.accountID == toSub.accountID, "different account");
    require(fromSub.quoteCurrency == toSub.quoteCurrency, "different currency");
    require(fromSub.balance >= int64(numTokens), "insufficient balance");

    // Account storage acc = _requireAccount( sub.accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashTransfer(fromSubAcc, toSubAcc, numTokens, nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    int256 totalVal = _getTotalValue(fromSub);
    require(int64(numTokens) <= totalVal, "withdrawal amount > total value");

    // Update balance
    fromSub.balance -= int64(numTokens);
    toSub.balance += int64(numTokens);
  }
}
