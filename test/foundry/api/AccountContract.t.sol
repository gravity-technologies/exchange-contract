// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";

contract AccountContractTest is Base_Test {
  function testCreateAccount() public {
    int64 timestamp = 1;
    uint64 txID = 1;
    address accountID = users.walletOne;

    // grvtExchange.createAccount(address(0x123), address(0x456), address(0x789));
  }
}
