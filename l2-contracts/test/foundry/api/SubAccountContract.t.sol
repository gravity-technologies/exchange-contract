// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/SubAccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";
import "./APIBase.t.sol";

contract SubAccountContractTest is APIBase {
  function testCreateSubAccount() public {
    createAccountHelper(users.walletOne, users.walletOnePrivateKey);
    progressToNextTxn();
    address accountID = users.walletOne;
    uint64 subAccID = uint64(random());
    createSubAccountHelper(users.walletOne, users.walletOnePrivateKey, accountID, subAccID);
  }

  function testAddSubAccountSigner() public {
    createAccountHelper(users.walletOne, users.walletOnePrivateKey);
    progressToNextTxn();
    address accountID = users.walletOne;
    uint64 subAccID = uint64(random());
    createSubAccountHelper(users.walletOne, users.walletOnePrivateKey, accountID, subAccID);
    progressToNextTxn();
    addSubAccountSignerHelper(
      users.walletOne,
      users.walletOnePrivateKey,
      subAccID,
      users.walletTwo,
      SubAccountPermTrade
    );
    progressToNextTxn();
  }
}
