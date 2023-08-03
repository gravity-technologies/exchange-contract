// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {State} from "./DataStructure.sol";
import {AccountContract} from "./api/AccountContract.sol";
import {AccountRecoveryContract} from "./api/AccountRecoveryContract.sol";
import {SubAccountContract} from "./api/SubAccountContract.sol";
import {TransferContract} from "./api/TransferContract.sol";
import "hardhat/console.sol";
import {BlackScholes as BS} from "./blackscholes/BlackScholes.sol";

// TODO: do we need to emit event for each of the account/subaccount CRUD?
contract GRVTExchange is AccountContract, AccountRecoveryContract, SubAccountContract, TransferContract {
  State state;

  function _getState()
    internal
    view
    override(AccountContract, AccountRecoveryContract, SubAccountContract, TransferContract)
    returns (State storage)
  {
    return state;
  }

  function bs() external pure returns (uint, uint) {
    uint expiryDays = 30 days;
    uint vol = 0;
    uint spot = 100e19;
    uint strike = 102e19;
    int rate = 0;

    BS.BlackScholesInputs memory input = BS.BlackScholesInputs(expiryDays, vol, spot, strike, rate);
    (uint call, uint put) = BS.optionPrices(input);
    console.log("call", call, "put", put);
    return (call, put);
  }
}
