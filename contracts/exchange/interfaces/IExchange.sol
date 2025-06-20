pragma solidity ^0.8.20;

import "../interfaces/IAccount.sol";
import "../interfaces/ISubAccount.sol";
import "../interfaces/IConfig.sol";
import "../interfaces/IMarginConfig.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ITrade.sol";
import "../interfaces/ITransfer.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IWalletRecovery.sol";
import "../interfaces/IAssertion.sol";
import "../interfaces/IGetter.sol";
import "../interfaces/ICurrency.sol";

import "../types/DataStructure.sol";
import {DepositProxy} from "../../DepositProxy.sol";

interface IGRVTExchange is
  IAccount,
  ISubAccount,
  IConfig,
  IMarginConfig,
  IOracle,
  ITrade,
  ITransfer,
  IVault,
  IWalletRecovery,
  IAssertion,
  IGetter,
  ICurrency
{
  function getLastTxID() external view returns (uint64);

  function getDepositProxyBytecodeHash() external view returns (bytes32);

  function getDepositProxyBeacon() external view returns (address);

  function getDepositProxy(address accountID) external view returns (DepositProxy);
}
