// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./GRVTExchange.sol";
import "./api/ReadStateContract.sol";

contract GRVTExchangeTest is ReadStateContract, GRVTExchange {}
