// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/SubAccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";
import "./APIBase.t.sol";

contract WalletRecoveryContractTest is APIBase {
  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
  address internal accSigner;
  address internal accSignerRecoveryAddressOne;
  address internal accSignerRecoveryAddressTwo;

  address internal subAccSigner;
  address internal subAccSignerRecoveryAddressOne;
  address internal subAccSignerRecoveryAddressTwo;

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
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressOne, accSigner);
    progressToNextTxn();
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressTwo, accSigner);
    progressToNextTxn();
  }

  function testAddDuplicateRecoveryAddressAccSignerNoOp() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressOne, accSigner);
    progressToNextTxn();
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressOne, accSigner);
    progressToNextTxn();
  }

  function testAddRecoveryAddressAccSignerWithIncorrectWallet() public {
    vm.expectRevert("invalid signer");
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      accSignerRecoveryAddressOne,
      accSigner
    );
    progressToNextTxn();
  }

  function testAddSubAccountSignerRecoveryAddress() public {
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      subAccSignerRecoveryAddressOne,
      subAccSigner
    );
    progressToNextTxn();
    addRecoveryAddressHelper(
      subAccSigner,
      users.walletFourPrivateKey,
      accountID,
      subAccSignerRecoveryAddressTwo,
      subAccSigner
    );
    progressToNextTxn();
  }

  function testRemoveAccSignerRecoveryAddress() public {
    addRecoveryAddressHelper(accSigner, users.walletOnePrivateKey, accountID, accSignerRecoveryAddressOne, accSigner);
    progressToNextTxn();
    removeRecoveryAddressHelper(
      accSigner,
      users.walletOnePrivateKey,
      accountID,
      accSigner,
      accSignerRecoveryAddressOne
    );
    progressToNextTxn();
  }
}
