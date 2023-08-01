// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from '../DataStructure.sol';

abstract contract SubAccountAPI {
  function _getState() internal virtual returns (State storage);
}
