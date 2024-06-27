// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";
import "./APIBase.t.sol";

contract AccountContractTest is APIBase {
  function testCreateAccount() public {
    createAccountHelper(users.walletOne, users.walletOnePrivateKey);
    txNonce++;
  }

  function testAddAccountSigner() public {
    createAccountHelper(users.walletOne, users.walletOnePrivateKey);
    progressToNextTxn();
    address accountID = users.walletOne;
    uint64 permissions = AccountPermInternalTransfer | AccountPermExternalTransfer | AccountPermWithdraw;
    address[] memory signerWallets = new address[](1);
    uint256[] memory signerPrivateKeys = new uint256[](1);
    signerWallets[0] = address(users.walletOne);
    signerPrivateKeys[0] = users.walletOnePrivateKey;
    addAccountSignerHelper(signerWallets, signerPrivateKeys, accountID, permissions, users.walletTwo);
    progressToNextTxn();
  }
}
