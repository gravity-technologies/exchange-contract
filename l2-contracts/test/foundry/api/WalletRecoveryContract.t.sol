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

  address internal newAddressOne;
  address internal newAddressTwo;

  address internal accountID;
  uint64 internal subAccIDOne;
  uint64 internal subAccIDTwo;

  function setUp() public override {
    super.setUp();
    accSigner = users.walletOne;
    accSignerPrivateKey = users.walletOnePrivateKey;
    accSignerRecoveryAddressOne = users.walletTwo;
    accSignerRecoveryAddressOnePrivateKey = users.walletTwoPrivateKey;
    accSignerRecoveryAddressTwo = users.walletThree;
    accSignerRecoveryAddressTwoPrivateKey = users.walletThreePrivateKey;

    subAccSigner = users.walletFour;
    subAccSignerPrivateKey = users.walletFourPrivateKey;
    subAccSignerRecoveryAddressOne = users.walletFive;
    subAccSignerRecoveryAddressOnePrivateKey = users.walletFivePrivateKey;
    subAccSignerRecoveryAddressTwo = users.walletSix;
    subAccSignerRecoveryAddressTwoPrivateKey = users.walletSixPrivateKey;

    newAddressOne = users.walletSeven;
    newAddressTwo = users.walletEight;

    accountID = accSigner;
    createAccountHelper(accSigner, accSignerPrivateKey);
    progressToNextTxn();

    subAccIDOne = uint64(random());
    createSubAccountHelper(accSigner, accSignerPrivateKey, accountID, subAccIDOne);
    progressToNextTxn();
    addSubAccountSignerHelper(accSigner, accSignerPrivateKey, subAccIDOne, subAccSigner, SubAccountPermTrade);
    progressToNextTxn();

    subAccIDTwo = uint64(random());
    createSubAccountHelper(accSigner, accSignerPrivateKey, accountID, subAccIDTwo);
    progressToNextTxn();
    addSubAccountSignerHelper(accSigner, accSignerPrivateKey, subAccIDTwo, subAccSigner, SubAccountPermTrade);
    progressToNextTxn();
  }

  function testAddRecoveryAddressAccSigner() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressTwo);
    progressToNextTxn();
    // adding the same address twice is no-op
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressTwo);
    progressToNextTxn();
  }

  function testAddRecoveryAddressWithIncorrectWallet() public {
    vm.expectRevert("invalid signature");
    addRecoveryAddressHelper(subAccSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
  }

  function testRemoveRecoveryAddress() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    removeRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    addRecoveryAddressHelper(subAccSigner, subAccSignerPrivateKey, accountID, subAccSignerRecoveryAddressOne);
    progressToNextTxn();
    removeRecoveryAddressHelper(subAccSigner, subAccSignerPrivateKey, accountID, subAccSignerRecoveryAddressOne);
    progressToNextTxn();
  }

  function testRemoveRecoveryAddressWithIncorrectWallet() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    vm.expectRevert("invalid signature");
    removeRecoveryAddressHelper(subAccSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
  }

  function testRecoverAddress() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    recoverAddressHelper(
      accSignerRecoveryAddressOne,
      accSignerRecoveryAddressOnePrivateKey,
      accountID,
      accSigner,
      newAddressOne
    );
    progressToNextTxn();
    addRecoveryAddressHelper(subAccSigner, subAccSignerPrivateKey, accountID, subAccSignerRecoveryAddressOne);
    progressToNextTxn();
    recoverAddressHelper(
      subAccSignerRecoveryAddressOne,
      subAccSignerRecoveryAddressOnePrivateKey,
      accountID,
      subAccSigner,
      newAddressTwo
    );
  }

  function testRecoverAddressWithIncorrectRecoverySigner() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    vm.expectRevert("invalid signer");
    recoverAddressHelper(subAccSigner, subAccSignerPrivateKey, accountID, accSigner, newAddressOne);
    progressToNextTxn();
  }

  function testRecoverWalletWithUsedAddress() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    addRecoveryAddressHelper(subAccSigner, subAccSignerPrivateKey, accountID, accSignerRecoveryAddressTwo);
    progressToNextTxn();
    vm.expectRevert("new signer already exists");
    recoverAddressHelper(
      accSignerRecoveryAddressOne,
      accSignerRecoveryAddressOnePrivateKey,
      accountID,
      accSigner,
      subAccSigner
    );
  }

  function testRecoverWalletWithSigningAddress() public {
    addRecoveryAddressHelper(accSigner, accSignerPrivateKey, accountID, accSignerRecoveryAddressOne);
    progressToNextTxn();
    recoverAddressHelper(
      accSignerRecoveryAddressOne,
      accSignerRecoveryAddressOnePrivateKey,
      accountID,
      accSigner,
      newAddressOne
    );
  }

  function testSignerNotTaggedToAccount() public {
    vm.expectRevert("signer not tagged to account");
    addRecoveryAddressHelper(users.walletSeven, users.walletSevenPrivateKey, accountID, accSignerRecoveryAddressOne);
  }
}
