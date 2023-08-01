// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DataStructure.sol";

uint constant _MAX_NUM_LEGS = 10;

/**
 * @dev For the full list of validation, see https://docs.google.com/document/d/1S8qe5ulFvbn1ujmHTIYBO9uIJvpEai36bBw2lSqybak/edit
 * Note that these are the validation that trade data has to perform and not all of them are applicable to smart contract
 *
 * 1. Validate orderID (NOT APPLICABLE TO SMART CONTRACT)
 * Check that it is the first 128-bits of poseidon(R, S)
 * Check that it is unique amongst all active Orders
 * Or reject with invalidOrder
 *
 * 2. Validate orderID exhaustion (DONE IN TRADE API)
 * Check that orderID still has sufficient size left, or reject with signatureHashExhausted
 *
 * 3. Validate subAccountID (NOT APPLICABLE TO SMART CONTRACT)
 * Check that it aligns with Account Context, or reject with unauthorised
 *
 * 4. Validate TimeInForce (NOT APPLICABLE TO SMART CONTRACT)
 * Check that CreateOrder only has GTT/FOK/IOC
 * Check that CreateRfqQuote only has GTT/AON
 * Check that TradeRfq only has IOC
 * Check that CreateAxe only has GTT/AON
 * Check that TradeAxe only has IOC
 * Or reject with invalidOrder
 *
 * 5. Validate TimeInForce during trade
 * PARTIAL EXECUTION = GTT / IOC - allows partial size execution on each leg
 * FULL EXECUTION = AON / FOK - only allows full size execution on all legs
 * TAKER ONLY = IOC / FOK - only allows taker orders
 * MAKER OR TAKER = GTT / AON - allows maker or taker orders
 * Or reject with invalidOrder
 *
 * 6. Validate limitPrice
 * If isMarket == true, check that a limitPrice & ocoLimitPrice are not supplied
 * If isMarket == false, check that a limitPrice & ocoLimitPrice are supplied
 * If TimeInForce == AON || FOK, check the equivalents in order.Legs instead
 * limitPrice must be a multiple of tick_size.
 * Or reject with invalidOrder
 *
 * 7. Validate takerFeeCap/makerFeeCap (NOT APPLICABLE TO SMART CONTRACT)
 * Validate against AccountContext, that the cap listed in order is >= to the one in AccCtx.
 * Or reject with invalidOrder
 *
 * 8. Validate postOnly
 * If TimeInForce == IOC || FOK this must be false
 * Or reject with invalidOrder
 *
 * 9. Validate postOnly during trade
 * Validate that it is a maker order, or reject with FailPostOnly
 *
 * 10. Validate reduceOnly during trade
 * Validate that position size is reduced, or reject with FailReduceOnly
 *
 * 11. Validate legs
 * Check that it is not an empty list
 * Legs must be sorted by leg.derivative
 * Or reject with invalidOrder
 *
 * 12. Validate legs.derivative
 * Check that it belongs to the list of currently active instruments
 * Or reject with invalidOrder
 *
 * 13. Validate legs.numContracts
 * For Orderbook/AXE, numContracts must be >= than minSize
 * For RFQ, numContracts must be >= than minBlockSize
 * Or reject with invalidOrder
 *
 * 14. Validate legs.numContracts during trade
 * Check that it matches with RFQ & AXE structure/base ratio
 * Or reject with invalidOrder
 *
 * 15. Validate signature.signer  (Checked in DerivativeTrade API)
 * Check it is consistent with AccountContext
 * Or reject with unauthorised
 *
 * 16. Validate signature.expiration  (Checked in DerivativeTrade API)
 * Check expiration is after the current timestamp
 * Or reject with invalidOrder
 *
 * 17. Validate signature.r & s (Checked in DerivativeTrade API)
 * Signature follows EIP-712 format. See [External] Gravity Oracle Requirements
 * Sort limitPrice and ocoLimitPrice before generating signature
 * Or reject with invalidOrder
 *
 * 18. Validate metadata.clientOrderID
 * Check uniqueness within a sub account active orders, or reject with overlappingClientOrderId
 *
 * 19. Validate metadata.TriggerCondition (NOT APPLICABLE TO SMART CONTRACT)
 * At launch, only index will be supported
 *
 * 20. Validate metadata.TriggerPrice (NOT APPLICABLE TO SMART CONTRACT)
 * Validate TP is above current condition, or reject with invalidTriggerPrice
 * Validate SL is below current condition, or reject with invalidTriggerPrice
 *
 * 21. Validate state.status (NOT APPLICABLE TO SMART CONTRACT)
 * This should be created with open, or reject with invalidOrder
 *
 * 22. Validate state.rejectReason (NOT APPLICABLE TO SMART CONTRACT)
 * This should be unspecified during create, or reject with invalidOrder
 *
 * 23. Validate state.numContractsLeft (NOT APPLICABLE TO SMART CONTRACT)
 * This should be exactly the same as leg size during create, or reject with invalidOrder
 */
function _verifyOrder(Order calldata o, bool isMakerOrder) pure {
  // 1. Validate orderID
  // 2. Validate orderID exhaustion
  // 3. Validate subAccountID
  // 4. Validate TimeInForce
  // 5. Validate TimeInForce during trade
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
  if (o.reduceOnly) {
    // TODO
  }
  // 11. Validate legs are sorted by derivative ID
  OrderLeg[] calldata legs = o.legs;
  for (uint i = 1; i < legs.length; i++) {
    require(legs[i - 1].derivID < legs[i].derivID, "legs not sorted");
  }

  // check that there is oracle prices for the order

  // 12. Validate legs.derivative
  // 13. Validate legs.numContracts
  // 14. Validate legs.numContracts during trade
  // 15. Validate signature.signer
  // 16. Validate signature.expiration
  // 17. Validate signature.r & s
  // 18. Validate metadata.clientOrderID
  // 19. Validate metadata.TriggerCondition
  // 20. Validate metadata.TriggerPrice
  // 21. Validate state.status
  // 22. Validate state.rejectReason
  // 23. Validate state.numContractsLeft
}
