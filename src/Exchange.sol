// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, SubAccount, OrderState, PriceState, ConfigState, SafetyModulePool} from './DataStructure.sol';

contract GRVTExchange {
  address[] private addresses;

  // Accounts and Sessions
  mapping(uint32 => Account) accounts;
  mapping(uint32 => SubAccount) subaccounts;
  mapping(address => string) sessionKeys;

  // This tracks the number of contract that has been matched
  // Also used to prevent replay attack
  OrderState orders;

  // Oracle prices: Spot, Interest Rate, Volatility
  PriceState prices;

  // Configuration
  ConfigState config;

  // A Safety Module is created per quote + underlying currency pair
  mapping(uint8 => mapping(uint8 => SafetyModulePool)) safetyModule;

  // Transaction ID and time
  uint64 lastTransactionTime;
  uint64 lastTransactionID;

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

  function hello() public pure returns (string memory) {
    return 'hi';
  }
}
