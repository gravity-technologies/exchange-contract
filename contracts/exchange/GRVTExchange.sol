// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchange is Initializable {
  function initialize() public initializer {}

  function sampleFunction() public pure returns (int) {
    return 1;
  }

  function sampleFunctionTwo(int number) public returns (int) {
    return number;
  }
}
