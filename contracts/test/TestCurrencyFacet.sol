pragma solidity ^0.8.20;

import "../exchange/api/BaseContract.sol";
import "../exchange/types/DataStructure.sol";

// Test-only facet. Only diamond-cut into contracts deployed during test runs, never in production.
contract TestCurrencyFacet is BaseContract {
  // Chain IDs for non-production networks. Update if new test environments are added.
  uint256 private constant CHAIN_ID_LOCAL = 260; // era-test-node in local

  function seedCurrencies(
    uint16[] calldata ids,
    uint16[] calldata decimals
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(block.chainid == CHAIN_ID_LOCAL, "seedCurrencies: not available on production");
    require(state.lastTxID == 0, "only before initializeConfig");
    require(ids.length == decimals.length, "length mismatch");
    for (uint256 i = 0; i < ids.length; i++) {
      require(ids[i] > 0, "invalid id");
      CurrencyConfig storage config = state.currencyConfigs[ids[i]];
      config.id = ids[i];
      config.balanceDecimals = decimals[i];
    }
  }
}
