// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/SubAccountContract.sol";
import "./api/WalletRecoveryContract.sol";
import "./api/OracleContract.sol";
import "./api/TransferContract.sol";
import "./api/MarginConfigContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchange is
  Initializable,
  AccountContract,
  SubAccountContract,
  WalletRecoveryContract,
  OracleContract,
  TransferContract
{
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address initializeConfigSigner) public initializer {
    __ReentrancyGuard_init();

    // Initialize the config timelock rules
    _setDefaultConfigSettings();
    state.initializeConfigSigner = initializeConfigSigner;
  }
}
