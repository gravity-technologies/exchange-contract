// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTradeContract.sol";
import "./BaseContract.sol";
import "./signature/generated/TransferSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

abstract contract TransferContract is BaseTradeContract {
  /**
   * @notice Deposit collateral into a sub account
   * TODO: To review after bridging approach is confirmed
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param ethAddress Ethereum address of the depositor
   * @param toSubID Sub account to deposit into
   * @param numTokens Number of tokens to deposit
   * @param nonce Nonce of the transaction
   * @param sig Signature of the transaction
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    address ethAddress,
    uint64 toSubID,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(toSubID);

    // ---------- Signature Verification -----------
    _preventReplay(hashDeposit(ethAddress, toSubID, numTokens, nonce), sig);
    // ------- End of Signature Verification -------

    _requirePermission(sub, sig.signer, SubAccountPermDeposit);

    // numTokens are upcasted from uint64 -> int128, which is safe
    // TODO
    // sub.balanceE9 += int128(uint128(numTokens));
  }

  /**
   * @notice Withdraw collateral from a sub account. This will call external contract.
   * This follows the Checks-Effects-Interactions pattern to mitigate reentrancy attack.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromSubID Sub account to withdraw from
   * @param toEthAddress Ethereum address of the withdrawer
   * @param numTokens Number of tokens to withdraw
   * @param nonce Nonce of the transaction
   * @param sig Signature of the transaction
   **/
  function withdrawal(
    int64 timestamp,
    uint64 txID,
    uint64 fromSubID,
    address toEthAddress,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external nonReentrant {
    // _setSequence(timestamp, txID);
    // SubAccount storage sub = _requireSubAccount(fromSubID);
    // Account storage acc = _requireAccount(sub.accountID);
    // // ---------- Signature Verification -----------
    // _preventReplay(hashWithdrawal(fromSubID, toEthAddress, numTokens, nonce), sig);
    // // ------- End of Signature Verification -------
    // // numTokens are upcasted from uint64 -> int128, which is safe
    // int128 numTokensInt128 = int128(uint128(numTokens));
    // // 1. Ensure that the user can only withdraw up to the total value of the subaccount
    // // require(numTokensInt128 <= _getSubAccountUsdValue(sub), "overwithdraw");
    // _requirePermission(sub, sig.signer, SubAccountPermWithdrawal);
    // require(addressExists(acc.onboardedWithdrawalAddresses, toEthAddress), "invalid withdrawal address");
    // _fundPerp(sub);
    // // 2. Update collateral balance (charging a fee)
    // // sub.balanceE9 -= numTokensInt128 - WITHDRAWAL_FEE;
    // // 3. Verify valid total value
    // // TODO
    // // _requireValidSubAccountUsdValue(sub);
    // // 4. Call the bridging contract
    // // TODO
  }

  /**
   * @notice Transfer tokens from one sub account to another sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromSubID Sub account to transfer from
   * @param toSubID Sub account to transfer to
   * @param numTokens Number of tokens to transfer
   * @param nonce Nonce of the transaction
   * @param sig Signature of the transaction
   */
  function transfer(
    int64 timestamp,
    uint64 txID,
    address fromAccount,
    uint64 fromSubID,
    address toAccount,
    uint64 toSubID,
    uint64 numTokens,
    uint32 nonce,
    Signature calldata sig
  ) external {
    // _setSequence(timestamp, txID);
    // SubAccount storage fromSub = _requireSubAccount(fromSubID);
    // SubAccount storage toSub = _requireSubAccount(toSubID);
    // Account storage acc = _requireAccount(fromSub.accountID);
    // // Check if the signer has the permission to transfer
    // _requirePermission(fromSub, sig.signer, SubAccountPermTransfer);
    // // Check if the subaccounts belong to the same account, and the quote currency is the same
    // require(fromSub.accountID == toSub.accountID, "different account");
    // require(fromSub.quoteCurrency == toSub.quoteCurrency, "different currency");
    // // Check if the subaccount belongs to the whilelisted transfer subaccounts
    // require(addressExists(acc.onboardedTransferAccounts, toAccount), "invalid transfer subaccount");
    // // Run perp funding to update the balances of fromSub and toSub
    // _fundPerp(fromSub);
    // // numTokens are upcasted from uint64 -> int128, which is safe
    // int128 numTokensInt128 = int128(uint128(numTokens));
    // require(fromSub.balanceE9 >= numTokensInt128, "insufficient balance");
    // _fundPerp(toSub);
    // // Must have enough balances before transfering
    // // TODO
    // // require(numTokensInt128 <= _getSubAccountUsdValue(fromSub), "withdrawal amount > total value");
    // // ---------- Signature Verification -----------
    // _preventReplay(hashTransfer(fromSubID, toSubID, numTokens, nonce), sig);
    // // ------- End of Signature Verification -------
    // // Update balance
    // fromSub.balanceE9 -= numTokensInt128;
    // toSub.balanceE9 += numTokensInt128;
  }
}
