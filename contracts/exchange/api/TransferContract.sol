// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TradeContract.sol";
import "./signature/generated/TransferSig.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

abstract contract ERC20 {
  /**
   * @dev Moves a `value` amount of tokens from the caller's account to `to`.
   * Returns a boolean value indicating whether the operation succeeded.
   */
  function transfer(address to, uint256 value) external virtual returns (bool);
}

abstract contract TransferContract is TradeContract {
  /**
   * @notice Deposit collateral into a sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param accountID  account to deposit into
   * @param currency Currency to deposit
   * @param numTokens Number of tokens to deposit
   * @param sig Signature of the transaction
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    address fromEthAddress,
    address accountID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // Check if the deposit comes from a whilelisted deposit address
    // (address depositAddr, bool ok) = _getAddressConfig(ConfigID.DEPOSIT_ADDRESS);
    // require(ok && depositAddr == sig.signer, "invalid depositor");

    // ---------- Signature Verification -----------
    // _preventReplay(hashDeposit(fromEthAddress, accountID, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    Account storage account = _requireAccount(accountID);
    account.spotBalances[currency] += int64(numTokens);
  }

  /**
   * @notice Withdraw collateral from a sub account. This will call external contract.
   * This follows the Checks-Effects-Interactions pattern to mitigate reentrancy attack.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to withdraw from
   * @param recipient address of the recipient
   * @param currency Currency to withdraw
   * @param numTokens Number of tokens to withdraw
   * @param sig Signature of the transaction
   **/
  function withdraw(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    address recipient,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external nonReentrant {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(fromAccID);

    // Check if the signer has the permission to withdraw
    _requireAccountPermission(acc, sig.signer, AccountPermWithdraw);
    require(acc.onboardedWithdrawalAddresses[recipient], "invalid withdrawal address");

    // ---------- Signature Verification -----------
    // FIXME: disable for testnet testing
    // _preventReplay(hashWithdrawal(fromAccID, recipient, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    // TODO: charge withdrawal fee
    int64 withdrawalFee = 0;
    int64 delta = int64(numTokens) + withdrawalFee;

    require(delta <= acc.spotBalances[currency], "insufficient balance");
    acc.spotBalances[currency] -= delta;

    // Call token's ERC20 contract to initiate a transfer
    ERC20 erc20Contract = ERC20(getCurrencyERC20Address(currency));
    bool success = erc20Contract.transfer(recipient, numTokens);
    require(success, "transfer failed");
  }

  function getCurrencyERC20Address(Currency currency) private view returns (address) {
    if (currency == Currency.USDT) {
      (address addr, bool ok) = _getAddressConfig(ConfigID.ERC20_USDT_ADDRESS);
      require(ok, "invalid USDT address");
      return addr;
    }
    revert("invalid currency");
  }

  /**
   * @notice Transfer tokens from one sub account to another sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromSubID Sub account to transfer from
   * @param toSubID Sub account to transfer to
   * @param currency Currency to transfer
   * @param numTokens Number of tokens to transfer
   * @param sig Signature of the transaction
   */
  function transfer(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    _preventReplay(hashTransfer(fromAccID, fromSubID, toAccID, toSubID, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    // 1. Same account
    if (fromAccID == toAccID) {
      require(fromSubID != toSubID, "self transfer");
      if (fromSubID == 0) {
        // 1.1 Main -> Sub
        _transferMainToSub(fromAccID, toSubID, currency, numTokens, sig);
      } else if (toSubID == 0) {
        // 1.2 Sub -> Main
        _transferSubToMain(fromSubID, fromAccID, currency, numTokens, sig);
      } else {
        // 1.3 Sub -> Sub
        _transferSubToSub(fromSubID, toSubID, currency, numTokens, sig);
      }
    } else {
      // 2. Diff Account
      if (fromSubID == 0 && toSubID == 0) {
        // 2.1 Main -> Main
        _transferMainToMain(fromAccID, toAccID, currency, numTokens, sig);
      } else if (fromSubID == 0) {
        // 2.2 Main -> Sub
        _transferMainToSub(fromAccID, toSubID, currency, numTokens, sig);
      } else if (toSubID == 0) {
        // 2.3 Sub -> Main (TBD: should ban this case?)
        _transferSubToMain(fromSubID, toAccID, currency, numTokens, sig);
      } else {
        // 2.4 Sub -> Sub (TBD: should ban this case?)
        _transferSubToSub(fromSubID, toSubID, currency, numTokens, sig);
      }
    }
  }

  function _transferMainToMain(
    address fromAccID,
    address toAccID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) private {
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireAccountPermission(fromAcc, sig.signer, AccountPermInternalTransfer);
    require(int64(numTokens) <= fromAcc.spotBalances[currency], "insufficient balance");
    fromAcc.spotBalances[currency] -= int64(numTokens);
    _requireAccount(toAccID).spotBalances[currency] += int64(numTokens);
  }

  function _transferMainToSub(
    address fromAccID,
    uint64 toSubID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) private {
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireAccountPermission(fromAcc, sig.signer, AccountPermInternalTransfer);
    require(int64(numTokens) <= fromAcc.spotBalances[currency], "insufficient balance");
    fromAcc.spotBalances[currency] -= int64(numTokens);
    _requireSubAccount(toSubID).spotBalances[currency] += int64(numTokens);
  }

  function _transferSubToMain(
    uint64 fromSubID,
    address toAccID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    _requireSubAccountPermission(fromSub, sig.signer, SubAccountPermTransfer);
    require(int64(numTokens) <= fromSub.spotBalances[currency], "insufficient balance");
    fromSub.spotBalances[currency] -= int64(numTokens);
    _requireValidSubAccountUsdValue(fromSub);
    _requireAccount(toAccID).spotBalances[currency] += int64(numTokens);
  }

  function _transferSubToSub(
    uint64 fromSubID,
    uint64 toSubID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    _requireSubAccountPermission(fromSub, sig.signer, SubAccountPermTransfer);
    require(int64(numTokens) <= fromSub.spotBalances[currency], "insufficient balance");
    fromSub.spotBalances[currency] -= int64(numTokens);
    _requireValidSubAccountUsdValue(fromSub);
    _requireSubAccount(toSubID).spotBalances[currency] += int64(numTokens);
  }
}
