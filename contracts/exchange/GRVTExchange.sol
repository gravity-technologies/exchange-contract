pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/SubAccountContract.sol";
import "./api/WalletRecoveryContract.sol";
import "./api/OracleContract.sol";
import "./api/TransferContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {DepositProxy} from "../DepositProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

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
    __AccessControl_init();

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

  function reinitializeMigrateDiamond(address _diamondOwner, address _diamondCutFacet) public reinitializer(2) {
    LibDiamond.setContractOwner(_diamondOwner);

    // Add the diamondCut external function from the diamondCutFacet
    IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
    bytes4[] memory functionSelectors = new bytes4[](1);
    functionSelectors[0] = IDiamondCut.diamondCut.selector;
    cut[0] = IDiamondCut.FacetCut({
      facetAddress: _diamondCutFacet,
      action: IDiamondCut.FacetCutAction.Add,
      functionSelectors: functionSelectors
    });
    LibDiamond.diamondCut(cut, address(0), "");
  }

  // Find facet for function that is called and execute the
  // function if a facet is found and return any value.
  fallback() external payable {
    LibDiamond.DiamondStorage storage ds;
    bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
    // get diamond storage
    assembly {
      ds.slot := position
    }
    // get facet from function selector
    address facet = address(bytes20(ds.facets[msg.sig]));
    require(facet != address(0), "Diamond: Function does not exist");
    // Execute external function from facet using delegatecall and return any value.
    assembly {
      // copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
      // execute function call using the facet
      let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
      // get any return value
      returndatacopy(0, 0, returndatasize())
      // return any return value or error back to the caller
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
