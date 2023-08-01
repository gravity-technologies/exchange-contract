// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ConfigID, State} from "./DataStructure.sol";
import {AccountContract} from "./api/AccountContract.sol";
import {AccountRecoveryContract} from "./api/AccountRecoveryContract.sol";
import {ConfigContract} from "./api/ConfigContract.sol";
import {SubAccountContract} from "./api/SubAccountContract.sol";

contract GRVTExchange is AccountContract, AccountRecoveryContract, ConfigContract, SubAccountContract {
  constructor(bytes32[] memory _initialConfig) {
    _setConfigTimelock();

    mapping(ConfigID => bytes32) storage configs = state.configs;
    for (uint i = 0; i < _initialConfig.length; i++) {
      configs[ConfigID(i)] = _initialConfig[i];
    }
  }
}
