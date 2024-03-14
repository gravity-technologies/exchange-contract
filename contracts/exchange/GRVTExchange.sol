// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/OracleContract.sol";
import "./api/SubAccountContract.sol";
import "./api/TransferContract.sol";
import "./api/WalletRecoveryContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract GRVTExchange is
  Initializable,
  AccountContract,
  OracleContract,
  SubAccountContract,
  TransferContract,
  WalletRecoveryContract
{
  function initialize() public initializer {
    console.log("HERE");
    __ReentrancyGuard_init();

    console.log("HERE1");
    // Initialize the config default values and timelock rules
    _setDefaultConfigSettings();
    console.log("HERE2");
  }
}
