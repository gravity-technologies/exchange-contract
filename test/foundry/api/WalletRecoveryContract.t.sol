// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/SubAccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";
import "./APIBase.t.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

contract WalletRecoveryContractTest is APIBase {
  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
  address internal accSigner;
  uint256 internal accSignerPrivateKey;
  address internal accSignerRecoveryAddressOne;
  uint256 internal accSignerRecoveryAddressOnePrivateKey;
  address internal accSignerRecoveryAddressTwo;
  uint256 internal accSignerRecoveryAddressTwoPrivateKey;

  address internal subAccSigner;
  uint256 internal subAccSignerPrivateKey;
  address internal subAccSignerRecoveryAddressOne;
  uint256 internal subAccSignerRecoveryAddressOnePrivateKey;
  address internal subAccSignerRecoveryAddressTwo;
  uint256 internal subAccSignerRecoveryAddressTwoPrivateKey;

  address internal accountID;
  uint64 internal subAccIDOne;
  uint64 internal subAccIDTwo;

  function setUp() public override {
    super.setUp();
    accSigner = users.walletOne;
    accSignerRecoveryAddressOne = users.walletTwo;
    accSignerRecoveryAddressTwo = users.walletThree;

    subAccSigner = users.walletFour;
    subAccSignerRecoveryAddressOne = users.walletFive;
    subAccSignerRecoveryAddressTwo = users.walletSix;

    accountID = accSigner;
    createAccountHelper(accSigner, users.walletOnePrivateKey);
    progressToNextTxn();

    subAccIDOne = uint64(random());
    createSubAccountHelper(accSigner, users.walletOnePrivateKey, accountID, subAccIDOne);
    progressToNextTxn();
    addSubAccountSignerHelper(accSigner, users.walletOnePrivateKey, subAccIDOne, subAccSigner, SubAccountPermTrade);
    progressToNextTxn();

    subAccIDTwo = uint64(random());
    createSubAccountHelper(accSigner, users.walletOnePrivateKey, accountID, subAccIDTwo);
    progressToNextTxn();
    addSubAccountSignerHelper(accSigner, users.walletOnePrivateKey, subAccIDTwo, subAccSigner, SubAccountPermTrade);
    progressToNextTxn();
  }

  function testAddRecoveryAddressAccSigner() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressOne);
    progressToNextTxn();
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressTwo);
    progressToNextTxn();
    // adding the same address twice is no-op
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressTwo);
    progressToNextTxn();
  }

  function testAddRecoveryAddressWithIncorrectWallet() public {
    vm.expectRevert("invalid signer");
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne
    );
    progressToNextTxn();
  }

  function testRemoveRecoveryAddress() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressOne);
    progressToNextTxn();
    removeRecoveryAddressHelper(
      accSigner,
      users.walletOnePrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne
    );
    progressToNextTxn();
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      subAccSigner,
      subAccSignerRecoveryAddressOne
    );
    progressToNextTxn();
    removeRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      subAccSigner,
      subAccSignerRecoveryAddressOne
    );
    progressToNextTxn();
  }

  function testRemoveRecoveryAddressWithIncorrectWallet() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressOne);
    progressToNextTxn();
    vm.expectRevert("invalid signer");
    removeRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne
    );
    progressToNextTxn();
  }

  function testRecoverAddress() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressOne);
    progressToNextTxn();
    recoverAddressHelper(
      accSignerRecoveryAddressOne,
      users.walletTwoPrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne,
      users.walletSeven
    );
    progressToNextTxn();
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      subAccSigner,
      subAccSignerRecoveryAddressOne
    );
    progressToNextTxn();
    recoverAddressHelper(
      subAccSignerRecoveryAddressOne,
      users.walletFivePrivateKey,
      accountID,
      subAccSigner,
      subAccSignerRecoveryAddressOne,
      users.walletEight
    );
  }

  function testRecoverAddressWithIncorrectWallet() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSigner, accSignerRecoveryAddressOne);
    progressToNextTxn();
    vm.expectRevert("invalid signer");
    recoverAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne,
      users.walletSeven
    );
    progressToNextTxn();
  }
}
