// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/SubAccountSig.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../api/APIBase.t.sol";
import "../Base.t.sol";
import "../types/Types.sol";

abstract contract TradeBase is APIBase {
  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
  Traders internal traders;

  function setUp() public virtual override {
    super.setUp();
    traders.traderOne = createTraders(users.walletOne, users.walletOnePrivateKey, uint64(random()));
    traders.traderTwo = createTraders(users.walletTwo, users.walletTwoPrivateKey, uint64(random()));
    traders.traderThree = createTraders(users.walletThree, users.walletThreePrivateKey, uint64(random()));
    traders.traderFour = createTraders(users.walletFour, users.walletFourPrivateKey, uint64(random()));
    traders.traderFive = createTraders(users.walletFive, users.walletFivePrivateKey, uint64(random()));
    traders.traderSix = createTraders(users.walletSix, users.walletSixPrivateKey, uint64(random()));
    traders.traderSeven = createTraders(users.walletSeven, users.walletSevenPrivateKey, uint64(random()));
  }

  function createTraders(address signer, uint256 privateKey, uint64 subAccID) public returns (Trader memory) {
    createAccountHelper(signer, privateKey);
    address accID = signer;
    progressToNextTxn();
    createSubAccountHelper(signer, privateKey, accID, subAccID);
    progressToNextTxn();
    return Trader({accID: accID, subAccID: subAccID, privateKey: users.walletOnePrivateKey, signer: users.walletOne});
  }
}
