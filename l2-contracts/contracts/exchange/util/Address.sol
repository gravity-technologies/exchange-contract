// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

function addressExists(address[] memory arr, address targetAddress) pure returns (bool) {
  for (uint256 i = 0; i < arr.length; ++i) {
    if (arr[i] == targetAddress) return true;
  }
  return false;
}

function addAddress(address[] storage arr, address targetAddress) {
  if (addressExists(arr, targetAddress)) revert("address exists");
  arr.push(targetAddress);
}

// Remove an address from an array.
// If the element is not found, revert()
// If preventRemovingLastElement = true, then the last element cannot be removed and the function will revert()
function removeAddress(address[] storage arr, address addressToRemove, bool preventRemovingLastElement) {
  for (uint256 i; i < arr.length; ++i) {
    if (arr[i] != addressToRemove) continue;
    require(!preventRemovingLastElement || arr.length > 1, "cannot remove last @");
    // Move the last element to the position of the element to be removed
    arr[i] = arr[arr.length - 1];
    arr.pop();
    return;
  }
  require(false, "not found");
}

function signerHasPerm(
  mapping(address => uint64) storage signers,
  address signerAddress,
  uint64 perm
) view returns (bool) {
  return (signers[signerAddress] & perm) != 0;
}
