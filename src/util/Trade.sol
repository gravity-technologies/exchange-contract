// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../types/DataStructure.sol";

uint constant _MAX_NUM_LEGS = 10;

/**
 * @dev For the full list of validation, see https://docs.google.com/document/d/1S8qe5ulFvbn1ujmHTIYBO9uIJvpEai36bBw2lSqybak/edit
 * Note that these are the validation that trade data has to perform and not all of them are applicable to smart contract
 */
function _verifyOrder(Order calldata o, bool isMakerOrder) pure {
  // 6. Validate limitPrice
  if (o.isMarket) {
    require(o.limitPrice == 0 && o.ocoLimitPrice == 0, "limit or oco price != 0");
  } else {
    require(o.limitPrice != 0 && o.ocoLimitPrice != 0, "missing limit or oco price");
  }
  // 7. Validate takerFeeCap/makerFeeCap
  // 8. Validate postOnly
  if (o.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL || o.timeInForce == TimeInForce.FILL_OR_KILL)
    require(!o.postOnly, "invalid postOnly & TIF");

  // 9. Validate postOnly during trade
  if (o.postOnly) require(isMakerOrder, "invalid postOnly");

  // 10. Validate reduceOnly during trade
  // if (o.reduceOnly) {
  //   // TODO
  // }
  // 11. Validate legs are sorted by derivative ID
  OrderLeg[] calldata legs = o.legs;
  for (uint i = 1; i < legs.length; i++) {
    require(legs[i - 1].assetID < legs[i].assetID, "legs not sorted");
  }
}
