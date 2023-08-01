// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from '../DataStructure.sol';

function addressExists(
  address[] memory arr,
  address targetAddress
) pure returns (bool) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] == targetAddress) {
      return true;
    }
  }
  return false;
}

function addAddress(address[] storage arr, address targetAddress) {
  if (addressExists(arr, targetAddress)) {
    revert('address already exists');
  }
  arr.push(targetAddress);
}

function removeAddress(
  address[] storage arr,
  address addressToRemove,
  bool preventRemovingLastElement
) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] != addressToRemove) {
      continue;
    }
    require(
      !preventRemovingLastElement || arr.length > 1,
      'cannot remove the last address'
    );
    // Move the last element to the position of the element to be removed
    arr[i] = arr[arr.length - 1];
    arr.pop();
    return;
  }
  revert('address not found');
}
