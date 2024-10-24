pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/SubAccountContract.sol";
import "./api/WalletRecoveryContract.sol";
import "./api/OracleContract.sol";
import "./api/TransferContract.sol";
import "./api/AssertionContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {DepositProxy} from "../DepositProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract GRVTExchange is
  Initializable,
  AccountContract,
  SubAccountContract,
  WalletRecoveryContract,
  OracleContract,
  TransferContract,
  AssertionContract
{
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the GRVTExchange contract with required addresses and configuration
  /// @param admin The address that will be granted the DEFAULT_ADMIN_ROLE and be able to manage roles of this contract
  /// @param chainSubmitter The address that will be granted the CHAIN_SUBMITTER_ROLE
  /// @param initializeConfigSigner The address authorized to sign the initializeConfig transaction
  /// @param beaconOwner The address that will own the deposit proxy beacon contract and therefore be able to upgrade it
  /// @param depositProxyProxyBytecodeHash The bytecode hash of BeaconProxy
  function initialize(
    address admin,
    address chainSubmitter,
    address initializeConfigSigner,
    address beaconOwner,
    bytes32 depositProxyProxyBytecodeHash
  ) public initializer {
    __ReentrancyGuard_init();

    // Initialize the config timelock rules
    _setDefaultConfigSettings();
    state.initializeConfigSigner = initializeConfigSigner;

    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _setupRole(CHAIN_SUBMITTER_ROLE, chainSubmitter);

    address depositProxy = address(new DepositProxy{salt: bytes32(0)}());
    state.depositProxyBeacon = new UpgradeableBeacon{salt: bytes32(0)}(depositProxy);
    state.depositProxyBeacon.transferOwnership(beaconOwner);
    state.depositProxyProxyBytecodeHash = depositProxyProxyBytecodeHash;
  }
}
