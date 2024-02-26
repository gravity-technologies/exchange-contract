// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ConfigID} from "./types/DataStructure.sol";
import "./api/AccountContract.sol";
import "./api/ConfigContract.sol";
import "./api/OracleContract.sol";
import "./api/SubAccountContract.sol";
import "./api/TradeContract.sol";
import "./api/TransferContract.sol";
import "./api/WalletRecoveryContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// import "hardhat/console.sol";

// import {BlackScholes as BS} from "./blackscholes/BlackScholes.sol";

contract GRVTExchange is
  Initializable,
  AccountContract,
  OracleContract,
  SubAccountContract,
  TradeContract,
  TransferContract,
  WalletRecoveryContract
{
  function initialize(bytes32[] memory _initialConfig) public initializer {
    __ReentrancyGuard_init();
    mapping(ConfigID => bytes32) storage configs = state.configs;
    for (uint i; i < _initialConfig.length; ++i) {
      configs[ConfigID(i)] = _initialConfig[i];
    }
  }
}
