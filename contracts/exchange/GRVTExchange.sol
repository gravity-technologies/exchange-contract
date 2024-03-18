// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/OracleContract.sol";
import "./api/SubAccountContract.sol";
import "./api/TransferContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchange is Initializable, AccountContract, OracleContract, SubAccountContract, TransferContract {
  function initialize() public initializer {
    __ReentrancyGuard_init();
    _setDefaultConfigSettings();
  }
}
