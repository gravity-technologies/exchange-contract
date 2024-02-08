// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../contracts/exchange/util/Address.sol";

contract AddressTest is Test {
  address[] public addresses;
  mapping(address => uint64) signers;

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

  function testSignerHasPerm() public {
    address signerAddress = address(0x123);
    uint64 perm = 1; // Example permission

    // Add signer with permission
    signers[signerAddress] = perm;

    // Test the function
    bool hasPerm = signerHasPerm(signers, signerAddress, perm);
    assert(hasPerm);
  }
}
