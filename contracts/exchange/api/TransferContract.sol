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

    // ---------- Signature Verification -----------
    // _preventReplay(hashDeposit(fromEthAddress, accountID, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    Account storage account = _requireAccount(accountID);
    account.spotBalances[currency] += int64(numTokens);
  }

  function getCurrencyERC20Address(Currency currency) private view returns (address) {
    if (currency == Currency.USDT) {
      (address addr, bool ok) = _getAddressConfig(ConfigID.ERC20_USDT_ADDRESS);
      require(ok, "invalid USDT address");
      return addr;
    }
    revert("invalid currency");
  }

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
