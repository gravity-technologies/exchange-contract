// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/util/Address.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

contract AddressTest is Test {
  address[] public addAddressesFix;
  address[] public removeAddressesFix;
  mapping(address => uint64) mockSigners;
  mapping(address => uint64) accountSigners;
  mapping(address => uint64) subAccountSigners;

  function testAddressExists() public pure {
    address[] memory arr = new address[](3);
    arr[0] = address(0x123);
    arr[1] = address(0x456);
    arr[2] = address(0x789);

    bool exists = addressExists(arr, address(0x456));
    assert(exists == true);

    exists = addressExists(arr, address(0x999));
    assert(exists == false);
  }

  function testAddAddress() public {
    addAddress(addAddressesFix, address(0x123));
    addAddress(addAddressesFix, address(0x456));
    addAddress(addAddressesFix, address(0x789));
    addAddress(addAddressesFix, address(0x999));
    assert(addAddressesFix.length == 4);
  }

  function testSignerHasPermMock() public {
    address signerAddress = address(0x123);
    uint64 perm = 1; // Example permission
    mockSigners[signerAddress] = perm;
    bool hasPerm = signerHasPerm(mockSigners, signerAddress, perm);
    assert(hasPerm);
  }

  function testSignerHasPermAccount() public {
    address signerAddress = address(0x123);
    accountSigners[signerAddress] = AccountPermInternalTransfer | AccountPermExternalTransfer | AccountPermWithdraw;
    assert(signerHasPerm(accountSigners, signerAddress, AccountPermInternalTransfer));
    assert(signerHasPerm(accountSigners, signerAddress, AccountPermExternalTransfer));
    assert(signerHasPerm(accountSigners, signerAddress, AccountPermWithdraw));
    assert(!signerHasPerm(accountSigners, signerAddress, AccountPermAdmin));
  }

  function testSignerHasPermSubAccount() public {
    address signerAddress = address(0x123);
    accountSigners[signerAddress] = SubAccountPermTransfer | SubAccountPermTrade;
    assert(signerHasPerm(accountSigners, signerAddress, SubAccountPermTransfer));
    assert(signerHasPerm(accountSigners, signerAddress, SubAccountPermTrade));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermAdmin));
  }

  function testRemoveAddress() public {
    addAddress(removeAddressesFix, address(0x123));
    addAddress(removeAddressesFix, address(0x456));
    addAddress(removeAddressesFix, address(0x789));
    addAddress(removeAddressesFix, address(0x999));
    assert(removeAddressesFix.length == 4);
    removeAddress(removeAddressesFix, address(0x123), false);
    assert(removeAddressesFix.length == 3);
    removeAddress(removeAddressesFix, address(0x789), false);
    assert(removeAddressesFix.length == 2);
    removeAddress(removeAddressesFix, address(0x456), false);
    assert(removeAddressesFix.length == 1);
    removeAddress(removeAddressesFix, address(0x999), false);
    assert(removeAddressesFix.length == 0);
    addAddress(removeAddressesFix, address(0x123));
    vm.expectRevert("cannot remove last @");
    removeAddress(removeAddressesFix, address(0x123), true);
    assert(removeAddressesFix.length == 1);
    vm.expectRevert("not found");
    removeAddress(removeAddressesFix, address(0x999), false);
    assert(removeAddressesFix.length == 1);
  }
}
