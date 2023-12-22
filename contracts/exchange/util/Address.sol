// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

function addressExists(address[] memory arr, address targetAddress) pure returns (bool) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] == targetAddress) return true;
  }
  return false;
}

function subAccountExists(uint64[] memory arr, uint64 subID) pure returns (bool) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] == subID) return true;
  }
  return false;
}

// Remove an a subAccountID from an array.
// If the element is not found, revert()
// If preventRemovingLastElement = true, then the last element cannot be removed and the function will revert()
function removeSubAccountID(uint64[] storage arr, uint64 subIDToRemove, bool preventRemovingLastElement) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] != subIDToRemove) continue;
    require(!preventRemovingLastElement || arr.length > 1, "cannot remove last @");
    // Move the last element to the position of the element to be removed
    arr[i] = arr[arr.length - 1];
    arr.pop();
    return;
  }
  require(false, "not found");
}

function addSubAccount(uint64[] storage arr, uint64 subID) {
  if (subAccountExists(arr, subID)) revert("subID exists");
  arr.push(subID);
}

function addAddress(address[] storage arr, address targetAddress) {
  if (addressExists(arr, targetAddress)) revert("address exists");
  arr.push(targetAddress);
}

// Remove an address from an array.
// If the element is not found, revert()
// If preventRemovingLastElement = true, then the last element cannot be removed and the function will revert()
function removeAddress(address[] storage arr, address addressToRemove, bool preventRemovingLastElement) {
  for (uint256 i = 0; i < arr.length; i++) {
    if (arr[i] != addressToRemove) continue;
    require(!preventRemovingLastElement || arr.length > 1, "cannot remove last @");
    // Move the last element to the position of the element to be removed
    arr[i] = arr[arr.length - 1];
    arr.pop();
    return;
  }
  require(false, "not found");
}
