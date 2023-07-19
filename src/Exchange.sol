// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from './DataStructure.sol';
import {AccountAPI} from './api/Account.sol';
import {SubAccountAPI} from './api/SubAccount.sol';

contract GRVTExchange is AccountAPI, SubAccountAPI {
  State state;

  function getState()
    internal
    view
    override(AccountAPI, SubAccountAPI)
    returns (State storage)
  {
    return state;
  }
}
