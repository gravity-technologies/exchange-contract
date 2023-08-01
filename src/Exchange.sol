// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from "./DataStructure.sol";
import {AccountContract} from "./api/AccountContract.sol";
import {AccountRecoveryContract} from "./api/AccountRecoveryContract.sol";
import {SubAccountContract} from "./api/SubAccountContract.sol";

// TODO: do we need to emit event for each of the account/subaccount CRUD?
contract GRVTExchange is AccountContract, AccountRecoveryContract, SubAccountContract {
  State state;

  function _getState()
    internal
    view
    override(AccountContract, AccountRecoveryContract, SubAccountContract)
    returns (State storage)
  {
    return state;
  }
}
