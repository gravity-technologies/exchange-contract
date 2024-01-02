// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ConfigID} from "./types/DataStructure.sol";
import "./api/AccountContract.sol";
import "./api/AccountRecoveryContract.sol";
import "./api/ConfigContract.sol";
import "./api/SubAccountContract.sol";
import "./api/TransferContract.sol";
import "./api/TradeContract.sol";

// import "hardhat/console.sol";

// import {BlackScholes as BS} from "./blackscholes/BlackScholes.sol";

contract GRVTExchange is AccountContract, AccountRecoveryContract, SubAccountContract, TransferContract, TradeContract {
  constructor(bytes32[] memory _initialConfig) {
    _setConfigTimelock();

    mapping(ConfigID => bytes32) storage configs = state.configs;
    for (uint i = 0; i < _initialConfig.length; i++) {
      configs[ConfigID(i)] = _initialConfig[i];
    }
  }

  function bs() external pure returns (uint, uint) {
    // uint expiry = 30 days;
    // uint vol = 25e16;
    // uint spot = 100e18;
    // uint strike = 105e18;
    // int rate = 5e16;

    // for (uint i = 0; i < 1; i++) {
    //   BS.BlackScholesInputs memory input = BS.BlackScholesInputs(expiry, vol, spot, strike, rate);
    //   (uint call, uint put) = BS.optionPrices(input);
    // }
    return (0, 0);
  }
}
