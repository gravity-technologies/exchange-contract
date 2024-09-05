// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/SubAccountContract.sol";
import "./api/WalletRecoveryContract.sol";
import "./api/OracleContract.sol";
import "./api/TransferContract.sol";
import "./api/LiquidationContract.sol";
import "./api/AssertionContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchange is
  Initializable,
  AccountContract,
  SubAccountContract,
  WalletRecoveryContract,
  OracleContract,
  TransferContract,
  LiquidationContract,
  AssertionContract
{
  function initialize() public initializer {
    __ReentrancyGuard_init();

    // Initialize the config default values and timelock rules
    _setDefaultConfigSettings();
  }
}
