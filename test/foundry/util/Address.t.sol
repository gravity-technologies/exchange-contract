// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../contracts/exchange/util/Address.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

contract AddressTest is Test {
  address[] public addresses;
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
    addAddress(addresses, address(0x123));
    addAddress(addresses, address(0x456));
    addAddress(addresses, address(0x789));
    addAddress(addresses, address(0x999));
    assert(addresses.length == 4);
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
    accountSigners[signerAddress] = SubAccountPermDeposit | SubAccountPermWithdrawal | SubAccountPermTrade;
    assert(signerHasPerm(accountSigners, signerAddress, SubAccountPermDeposit));
    assert(signerHasPerm(accountSigners, signerAddress, SubAccountPermWithdrawal));
    assert(signerHasPerm(accountSigners, signerAddress, SubAccountPermTrade));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermAdmin));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermTransfer));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermAddSigner));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermRemoveSigner));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermUpdateSignerPermission));
    assert(!signerHasPerm(accountSigners, signerAddress, SubAccountPermChangeMarginType));
  }
}
