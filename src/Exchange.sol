// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract GRVTExchange {
  address[] private addresses;

  function addAddress(address _newAddress) public {
    addresses.push(_newAddress);
  }

  function findAddress(address _searchAddress) public view returns (uint256) {
    for (uint256 i = 0; i < addresses.length; i++) {
      if (addresses[i] == _searchAddress) {
        return i;
      }
    }
    revert('Address not found');
  }

  struct Account {
    uint id;
  }

  struct SubAccount {
    uint id;
  }

  function hello() public pure returns (string memory) {
    return 'hi';
  }
}
