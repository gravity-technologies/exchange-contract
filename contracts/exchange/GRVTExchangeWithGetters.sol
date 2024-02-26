// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./GRVTExchange.sol";
import "./api/StateGetter.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchangeWithGetters is Initializable, GRVTExchange {}
