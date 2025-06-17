pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "../types/DataStructure.sol";

contract CurrencyContract is ConfigContract {
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

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, id, balanceDecimals));
  }
}
