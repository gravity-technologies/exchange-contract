pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "../types/DataStructure.sol";
import "../interfaces/ICurrency.sol";

contract CurrencyContract is ICurrency, ConfigContract {
  function addCurrency(
    int64 timestamp,
    uint64 txID,
    uint16 id,
    uint16 balanceDecimals
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    require(id > 0, "invalid currency id");
    CurrencyConfig storage config = state.currencyConfigs[id];

    if (config.id != 0) {
      require(config.balanceDecimals == balanceDecimals, "change of decimals is not allowed");
      return; // no update needed
    }

    config.id = id;
    config.balanceDecimals = balanceDecimals;

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, id, balanceDecimals));
  }
}
