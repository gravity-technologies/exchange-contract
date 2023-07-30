// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from './DataStructure.sol';
import {AccountContract} from './api/AccountContract.sol';
import {AccountRecoveryContract} from './api/AccountRecoveryContract.sol';
import {SubAccountAPI} from './api/SubAccount.sol';

contract GRVTExchange is AccountContract, AccountRecoveryContract, SubAccountAPI {
  State state;

  function _getState()
    internal
    view
    override(AccountContract, AccountRecoveryContract, SubAccountAPI)
    returns (State storage)
  {
    return state;
  }
}
