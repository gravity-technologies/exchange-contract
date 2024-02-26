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

contract GRVTExchange is
  Initializable,
  AccountContract,
  ConfigContract,
  OracleContract,
  SubAccountContract,
  TradeContract,
  TransferContract,
  WalletRecoveryContract
{
  function initialize() public initializer {
    __ReentrancyGuard_init();
  }
}
