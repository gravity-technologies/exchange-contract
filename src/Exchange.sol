// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from './DataStructure.sol';
import {AccountAPI} from './api/Account.sol';
import {AccountRecoveryAPI} from './api/AccountRecovery.sol';
import {SubAccountAPI} from './api/SubAccount.sol';

contract GRVTExchange is AccountAPI, AccountRecoveryAPI, SubAccountAPI {
  State state;

  function _getState()
    internal
    view
    override(AccountAPI, AccountRecoveryAPI, SubAccountAPI)
    returns (State storage)
  {
    return state;
  }
}
