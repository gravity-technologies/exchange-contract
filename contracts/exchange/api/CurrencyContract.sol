pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";

contract CurrencyContract is BaseContract {
  function addCurrency(
    int64 timestamp,
    uint64 txID,
    uint16 id,
    uint16 balanceDecimals
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    require(id > 0, "invalid currency id");
    require(state.currencyConfigs[id].id == 0, "currency already exists");
    CurrencyConfig storage config = state.currencyConfigs[id];
    config.id = id;
    config.balanceDecimals = balanceDecimals;
  }
}
