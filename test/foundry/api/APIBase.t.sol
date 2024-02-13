// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/SubAccountSig.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";

abstract contract APIBase is BaseTest {
  function createAccountHelper(address wallet, uint256 privateKey) public {
    uint256 expiryTimestamp = currentTimestamp + (3 days);
    int64 currentTimestapInt64 = int64(int256(currentTimestamp));
    int64 expiry = int64(int256(expiryTimestamp));
    uint32 sigNonce = random();
    address accountID = wallet;
    bytes32 structHash = hashCreateAccount(accountID, sigNonce);
    Signature memory sig = getUserSig(wallet, privateKey, DOMAIN_HASH, structHash, expiry, sigNonce);
    grvtExchange.createAccount(currentTimestapInt64, txNonce, accountID, sig);
  }

  function addAccountSignerHelper(
    address[] memory wallets,
    uint256[] memory privateKeys,
    address accountID,
    uint64 permissions,
    address signer
  ) public {
    uint256 expiryTimestamp = currentTimestamp + (3 days);
    int64 currentTimestapInt64 = int64(int256(currentTimestamp));
    int64 expiry = int64(int256(expiryTimestamp));
    uint32 sigNonce = random();
    Signature[] memory sigs = new Signature[](wallets.length);
    for (uint i = 0; i < wallets.length; i++) {
      bytes32 structHash = hashAddAccountSigner(accountID, signer, permissions, sigNonce);
      Signature memory sig = getUserSig(wallets[i], privateKeys[i], DOMAIN_HASH, structHash, expiry, sigNonce);
      sigs[i] = sig;
    }

    grvtExchange.addAccountSigner(currentTimestapInt64, txNonce, accountID, signer, permissions, sigNonce, sigs);
  }

  function createSubAccountHelper(address wallet, uint256 privateKey, address accountID, uint64 subAccID) public {
    uint256 expiryTimestamp = currentTimestamp + (3 days);
    int64 currentTimestapInt64 = int64(int256(currentTimestamp));
    int64 expiry = int64(int256(expiryTimestamp));
    uint32 sigNonce = random();
    bytes32 structHash = hashCreateSubAccount(
      accountID,
      subAccID,
      Currency.USDC,
      MarginType.PORTFOLIO_CROSS_MARGIN,
      sigNonce
    );
    Signature memory sig = getUserSig(wallet, privateKey, DOMAIN_HASH, structHash, expiry, sigNonce);
    grvtExchange.createSubAccount(
      currentTimestapInt64,
      txNonce,
      accountID,
      subAccID,
      Currency.USDC,
      MarginType.PORTFOLIO_CROSS_MARGIN,
      sigNonce,
      sig
    );
  }
}
