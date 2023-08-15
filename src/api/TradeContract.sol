// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./BaseTradeContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../DataStructure.sol";
import "../util/Address.sol";
import "../util/Trade.sol";

abstract contract TradeContract is ConfigContract, BaseTradeContract {
  /**
   * @notice Trade derivatives between 2 subaccounts
   * 1.	Verify signature
   * 2.	Verify trade info
   * 3. Verify that taker and maker have permission to trade on the subaccount
   * 4. Lazily perform perpetual funding to update balances of both taker and makers
   * 5. Update position balances involved in the trade
   * 6. Update collateral balances for each subaccount
   * 7. Collect fees from taker and makers into the GRVT subaccount
   * 8. Prevent replay and update order fulfillment status
   * 9. Perform total value check for taker and makers. If it fails, revert all changes.
   *
   * TODO: settle on the int size for balances
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param trade the trade payload
   */
  function derivativeTrade(uint64 timestamp, uint64 txID, Trade calldata trade) public nonReentrant {
    _setSequence(timestamp, txID);

    // Validation
    _verifySignatureAndPermissions(trade);
    _verifyTrade(trade);

    SubAccount storage taker = _requireSubAccount(trade.takerOrder.subAccountID);

    // Run perpetual funding
    _perpFunding(taker);

    // Update balances
    uint fees = _updateBalances(taker, trade.makerOrders);

    // // Run total value check for taker and each maker
    _verifyValidTotalValue(taker, trade.makerOrders);

    // // Deposit fees
    _depositFee(uint128(fees));

    // TODO: Update the fulfilment of each order leg
    // Maintain, update the remaining quantity for each taker and maker order.
  }

  /**
   * @dev Update balance of each leg
   * 1. Go through the list of maker orders to match
   * 2. For each maker match, iterate through each leg
   * 3. For each leg, update the balance of the maker and taker's corresponding position
   */
  function _updateBalances(SubAccount storage taker, OrderMatch[] calldata matches) internal returns (uint128) {
    uint128 fees;

    for (uint i = 0; i < matches.length; i++) {
      OrderMatch calldata om = matches[i];
      SubAccount storage maker = _requireSubAccount(om.makerOrder.subAccountID);
      _perpFunding(maker);

      for (uint j = 0; j < om.numContractsMatched.length; j++) {
        OrderLeg calldata makerLeg = om.makerOrder.legs[j];
        uint128 qty = om.numContractsMatched[j];
        require(qty > 0, "invalid qty");

        // Update position balances
        (int128 takerCollDelta, int128 makerCollDelta) = _updatePositionBalances(
          makerLeg,
          _getPosition(taker, makerLeg.derivative),
          _getPosition(maker, makerLeg.derivative),
          qty
        );

        // Compute fees and update collateral balances
        uint128 takerFee = _calculateFee(takerCollDelta, om.takerFeePercentageCharged);
        uint128 makerFee = _calculateFee(makerCollDelta, om.makerFeePercentageCharged);
        taker.balance += takerCollDelta - int128(takerFee);
        maker.balance += makerCollDelta - int128(makerFee);
        fees += takerFee + makerFee;
      }
    }

    return fees;
  }

  function _updatePositionBalances(
    OrderLeg calldata leg,
    DerivativePosition storage takerPos,
    DerivativePosition storage makerPos,
    uint128 qty
  ) internal returns (int128 takerCollDelta, int128 makerCollDelta) {
    int128 qtyInt128 = int128(qty);
    int128 legValueInt128 = int128(leg.limitPrice * qty);

    if (leg.isBuyingContract) {
      takerPos.contractBalance -= qtyInt128;
      makerPos.contractBalance += qtyInt128;
      // TODO: check the math here. On paper this downcasting is wrong, but in practice we might never use the full range of int128 for leg value anyway.
      // To check with TradeData on the maximum value of legValue
      return (legValueInt128, -legValueInt128);
    }

    takerPos.contractBalance += qtyInt128;
    makerPos.contractBalance -= qtyInt128;
    // TODO: check the math here. On paper this downcasting is wrong, but in practice we might never use the full range of int128 for leg value anyway.
    // To check with TradeData on the maximum value of legValue
    return (-legValueInt128, legValueInt128);
  }

  function _calculateFee(int128 collDelta, uint32 feePercentage) internal pure returns (uint128 fee) {
    return _abs(collDelta * int128(uint128(feePercentage)));
  }

  function _abs(int128 x) private pure returns (uint128) {
    return x >= 0 ? uint128(x) : uint128(-x);
  }

  function _depositFee(uint128 fee) private {
    _requireSubAccount(_getAddressCfg(CfgID.FEE_SUB_ACCOUNT_ID)).balance += int128(fee);
  }

  // Verify that the signatures are valid and that the taker and maker has permission to trade
  function _verifySignatureAndPermissions(Trade calldata trade) private view {
    Order calldata takerOrder = trade.takerOrder;
    uint64 timestamp = state.timestamp;
    _requireValidSig(timestamp, hashOrder(takerOrder), takerOrder.signature);

    // check that taker has permission to trade
    _requireTradePermission(takerOrder.signature, takerOrder.subAccountID);

    uint numMakerOrders = trade.makerOrders.length;
    for (uint i = 0; i < numMakerOrders; i++) {
      Order calldata order = trade.makerOrders[i].makerOrder;
      _requireValidSig(timestamp, hashOrder(order), order.signature);

      // check that maker has permission to trade
      _requireTradePermission(order.signature, order.subAccountID);
    }
  }

  function _requireTradePermission(Signature calldata sig, address orderSubAccountID) private view {
    // check if this is a session key
    SubAccount storage sub;
    // Check if the signer is from a session address. If it is, then get the account owning this session.
    // Otherwise, the signer address is the subaccount ID.
    address subFromSession = state.sessionToSubAccount[sig.signer];
    if (subFromSession == address(0)) sub = _requireSubAccount(sig.signer);
    else sub = _requireSubAccount(subFromSession);
    require(orderSubAccountID == sub.id, "subaccount cannot trade");
    _requirePermission(sub, sig.signer, SubAccountPermTrade);
  }

  function _getPosition(SubAccount storage sub, uint128 derivID) private view returns (DerivativePosition storage) {
    // FIXME: check if this is a perp/future/option
    return get(sub.options, derivID);
  }

  // TODO: optimization: precompute the signature and pass those around to save gas
  function _verifyTrade(Trade calldata trade) private view {
    Order calldata takerOrder = trade.takerOrder;
    OrderMatch[] calldata makerOrders = trade.makerOrders;
    TimeInForce tif = takerOrder.timeInForce;
    bytes32 takerOrderID = hashOrder(takerOrder);
    uint numMakers = trade.makerOrders.length;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint numLegs = takerLegs.length;
    require(numMakers > 0, "empty maker orders");
    numLegs = takerLegs.length;

    // 1. Verify each order
    _verifyOrder(takerOrder, false);
    address feeSubID = _getAddressCfg(CfgID.FEE_SUB_ACCOUNT_ID);
    require(takerOrder.subAccountID != feeSubID, "fee subaccount cannot be taker");
    for (uint j = 0; j < numMakers; j++) {
      Order calldata makerOrder = makerOrders[j].makerOrder;
      require(makerOrder.legs.length == numLegs, "inconsistent num legs");
      _verifyOrder(makerOrders[j].makerOrder, true);

      require(makerOrder.subAccountID != takerOrder.subAccountID, "self-trade");
      require(makerOrder.subAccountID != feeSubID, "fee subaccount cannot be maker");
    }

    // 2. Each derivative must have a price
    for (uint i = 0; i < numLegs; i++) {
      _getDerivPrice(takerLegs[i].derivative);
    }

    // 3. If full order, just perform signature replay prevention
    if (tif != TimeInForce.GOOD_TILL_TIME && tif != TimeInForce.IMMEDIATE_OR_CANCEL) {
      require(!state.signatures.fullDerivativeOrderMatched[takerOrderID], "order is replayed");
      for (uint i = 0; i < numMakers; i++) {
        bytes32 makerOrderID = hashOrder(makerOrders[i].makerOrder);
        require(!state.signatures.fullDerivativeOrderMatched[makerOrderID], "order is replayed");
      }
      return;
    }

    // 4. If partial, then we have to track the quantities are still enough
    // Assert that for each maker order, the matched leq qty is less than the makerOrder.leg qty
    // Assert that for taker order, the total matched qty per leg is less than the takerOrder.leg qty

    // A map that keep track of the matched qty for each leg for an order
    mapping(bytes32 => uint64[]) storage preMatched = state.signatures.partialDerivativeOrderMatched;

    uint64[] storage preMatchedTaker = preMatched[takerOrderID];
    for (uint i = 0; i < numLegs; i++) {
      // Total quantity matched per leg
      uint total = 0;
      Order calldata makerOrder = makerOrders[i].makerOrder;
      for (uint j = 0; j < numMakers; j++) {
        uint64 qty = makerOrders[j].numContractsMatched[i];
        uint64[] storage preMatchedMaker = preMatched[hashOrder(makerOrder)];
        // There's no risk of out-of-bound error here, since trade has already been validated to be correct
        require(preMatchedMaker[i] + qty <= makerOrder.legs[i].contractSize, "insufficient qty");
        total += qty;
      }
      require(total + preMatchedTaker[i] <= takerLegs[i].contractSize, "insufficient qty");
    }
  }

  function _verifyValidTotalValue(SubAccount storage taker, OrderMatch[] calldata matches) private view {
    // Run total value check for taker and each maker
    _requireValidTotalValue(taker);
    uint numMakerOrders = matches.length;
    for (uint i = 0; i < numMakerOrders; i++) {
      SubAccount storage maker = _requireSubAccount(matches[i].makerOrder.subAccountID);
      _requireValidTotalValue(maker);
    }
  }
}
