// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DataStructure.sol";
import "./HelperContract.sol";
import "./signature/generated/SafetyModuleSig.sol";

contract SafetyModuleContract is HelperContract {
  /// @dev Deposit tokens into the safety module.
  ///
  /// @param timestamp The timestamp of the deposit.
  /// @param txID The transaction ID associated with the deposit.
  /// @param subID The subaccount ID.
  /// @param quote The quote currency.
  /// @param underlying The underlying currency.
  /// @param numTokens The number of tokens to deposit.
  /// @param sig The signature of the transaction.
  function DepositIntoSafetyModule(
    uint256 timestamp,
    uint64 txID,
    address subID,
    Currency quote,
    Currency underlying,
    uint64 numTokens,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    _preventReplay(hashDepositSafetyMod(subID, quote, underlying, numTokens, nonce), sig);
  }

  /// @dev Withdraw tokens from the safety module.
  ///
  /// @param timestamp The timestamp of the withdrawal.
  /// @param txID The transaction ID associated with the withdrawal.
  /// @param subID The subaccount ID.
  /// @param quote The quote currency.
  /// @param underlying The underlying currency.
  /// @param numTokens The number of tokens to withdraw.
  /// @param sig The signature of the transaction.
  function WithdrawFromSafetyModule(
    uint256 timestamp,
    uint64 txID,
    address subID,
    Currency quote,
    Currency underlying,
    uint64 numTokens,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);
    _preventReplay(hashWithdrawSafetyMod(subID, quote, underlying, numTokens, nonce), sig);
    // TODO
  }
}
