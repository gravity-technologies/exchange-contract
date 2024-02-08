// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";

contract AccountContractTest is Base_Test {
  function testCreateAccount() public {
    int64 timestamp = 1;
    uint32 txNonce = 1;
    uint32 sigNonce = random();
    address accountID = users.walletOne;
    bytes32 structHash = hashCreateAccount(accountID, sigNonce);
    Signature memory sig = getUserSig(users.walletOne, 12, "", structHash, timestamp, txNonce);
    grvtExchange.createAccount(timestamp, txNonce, accountID, sig);
  }
}
