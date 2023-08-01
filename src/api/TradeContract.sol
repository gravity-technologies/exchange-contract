// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ConfigContract.sol";
import "./OracleContract.sol";
import "./PositionValueContract.sol";
import "./signature/generated/TradeSig.sol";
import "../DataStructure.sol";
import "../util/Address.sol";
import "../util/Trade.sol";

abstract contract TradeContract is PositionValueContract, ConfigContract {
  /**
   * @notice Trade derivatives between 2 subaccounts
   * 1. Verify signature (DONE)
   * 2. Verify trade info (DONE, 90%, need tests)
   * 2. Verify that taker and maker has permission to trade on the subaccount (DONE)
   * 3. Lazily perform perpetual funding to update balances of both taker and makers (DONE)
   * 4. Update position balances involves in the trade (DONE)
   * 5. Update collateral balances for each subaccount (DONE)
   * 6. Collect fees from taker and makers into GRVT subaccount (DONE)
   * 7. Prevent replay and update order fulfilment status
   * 8. Perform total value check for taker and makers. If fails, revert all changes (DONE)
   *
   * TODO: settle on the int size for balances
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param trade the trade payload
   */
  function derivativeTrade(uint64 timestamp, uint64 txID, Trade calldata trade) external {
    _setSequence(timestamp, txID);

    // Validation
    _verifySignatureAndPermissions(trade);
    _verifyTrade(trade);

    SubAccount storage taker = _requireSubAccount(trade.takerOrder.subAccountID);
    OrderMatch[] calldata matches = trade.makerOrders;

    // Run perpetual funding
    _perpFunding(taker);

    // Update balances
    uint fees = _updatePositionAndCollateralBalances(taker, matches);

    // Run total value check for taker and each maker
    _verifyValidTotalValue(taker, matches);

    // Deposit fees
    _depositFee(uint128(fees));

    // Update the fulfilment of each order leg
    // Maintain, update the remaining quantity for each taker and maker order.
    // Ensure that the remaining quantity is always >= 0
  }

  /// @dev Update balance of each leg
  /// 1. Go through list of maker orders match
  /// 2. For each maker match, go through each legs
  /// 3. For each leg, update the balance of the maker and taker's corresponding position
  function _updatePositionAndCollateralBalances(
    SubAccount storage taker,
    OrderMatch[] calldata matches
  ) internal returns (uint128) {
    uint128 fees;
    uint numMakerOrders = matches.length;

    for (uint i = 0; i < numMakerOrders; i++) {
      OrderMatch calldata om = matches[i];
      address makerID = om.makerOrder.subAccountID;

      SubAccount storage maker = _requireSubAccount(makerID);
      _perpFunding(maker);

      uint numLegs = om.numContractsMatched.length;
      uint128 totalValue;

      for (uint j = 0; j < numLegs; j++) {
        OrderLeg calldata makerLeg = om.makerOrder.legs[j];
        uint128 qty = om.numContractsMatched[j];
        require(qty > 0, "invalid qty");
        uint128 derivID = makerLeg.derivID;

        DerivativePosition storage takerPos = _getPosition(taker, derivID);
        DerivativePosition storage makerPos = _getPosition(maker, derivID);
        uint128 legValue = makerLeg.limitPrice * qty;
        totalValue += legValue;

        (uint128 takerPosQty, uint128 makerPosQty, int128 takerCollDelta, int128 makerCollDelta) = _executeTrade(
          makerLeg.isBuyingContract,
          qty,
          legValue,
          takerPos.contractBalance,
          makerPos.contractBalance
        );

        takerPos.contractBalance = takerPosQty;
        makerPos.contractBalance = makerPosQty;

        uint128 takerFee = _abs(takerCollDelta * int128(uint128(om.takerFeePercentageCharged)));
        uint128 makerFee = _abs(makerCollDelta * int128(uint128(om.makerFeePercentageCharged)));

        taker.balance += takerCollDelta - int128(takerFee);
        maker.balance += makerCollDelta - int128(makerFee);

        fees += takerFee + makerFee;
      }
    }

    return fees;
  }

  function _perpFunding(SubAccount storage sub) private {
    // uint128[] storage keys = sub.perps.keys;
    // mapping(uint128 => DerivativePosition) storage values = sub.perps.values;
    // uint count = keys.length;
    // int256 balanceDelta;
    // for (uint i = 0; i < count; i++) {
    //   DerivativePosition storage perp = values[keys[i]];
    //   uint256 price = _getDerivPrice(perp.id);
    //   balanceDelta += (int256(price) - perp.lastAppliedFundingIndex) * perp.contractBalance;
    // }
    // sub.balance += int128(uint128(balanceDelta));
  }

  function _abs(int128 x) private pure returns (uint128) {
    return x >= 0 ? uint128(x) : uint128(-x);
  }

  function _verifyValidTotalValue(SubAccount storage taker, OrderMatch[] calldata matches) private view {
    // Run total value check for taker and each maker
    require(_getTotalValue(taker) >= 0, "invalid total value");
    uint numMakerOrders = matches.length;
    for (uint i = 0; i < numMakerOrders; i++) {
      SubAccount storage maker = _requireSubAccount(matches[i].makerOrder.subAccountID);
      require(_getTotalValue(maker) >= 0, "invalid total value");
    }
  }

  function _depositFee(uint128 fee) private {
    SubAccount storage feeSub = _requireSubAccount(_getAddressCfg(CfgID.FEE_SUB_ACCOUNT_ID));
    feeSub.balance += int128(fee);
  }

  function _executeTrade(
    bool isBuyingContract,
    uint128 qty,
    uint128 legValue,
    uint128 takerPosQty,
    uint128 makerPosQty
  ) private pure returns (uint128, uint128, int128, int128) {
    int128 takerCollDelta;
    int128 makerCollDelta;

    if (isBuyingContract) {
      require(takerPosQty >= qty, "insufficient balance");
      takerPosQty -= qty;
      makerPosQty += qty;
      takerCollDelta = int128(legValue);
      makerCollDelta = -int128(legValue);
      // TODO: Add your logic here
    } else {
      require(makerPosQty >= qty, "insufficient balance");
      takerPosQty += qty;
      makerPosQty -= qty;
      takerCollDelta = -int128(legValue);
      makerCollDelta = int128(legValue);
      // TODO: Add your logic here
    }

    return (takerPosQty, makerPosQty, takerCollDelta, makerCollDelta);
  }

  // Verify that the signatures are valid and that the taker and maker has permission to trade
  function _verifySignatureAndPermissions(Trade calldata trade) private view {
    Order calldata takerOrder = trade.takerOrder;
    uint64 timestamp = state.timestamp;
    _requireValidSig(timestamp, hashOrder(takerOrder), takerOrder.signature);

    // check that taker has permission to trade
    SubAccount storage taker = _requireSubAccount(takerOrder.subAccountID);
    _requirePermission(taker, takerOrder.signature.signer, SubAccountPermTrade);

    for (uint i = 0; i < trade.makerOrders.length; i++) {
      Order calldata order = trade.makerOrders[i].makerOrder;
      _requireValidSig(timestamp, hashOrder(order), order.signature);

      // check that maker has permission to trade
      SubAccount storage maker = _requireSubAccount(order.subAccountID);
      _requirePermission(maker, order.signature.signer, SubAccountPermTrade);
    }
  }

  function _getPosition(SubAccount storage sub, uint128 derivID) private view returns (DerivativePosition storage) {
    // FIXME: check if this is a perp/future/option
    return get(sub.options, derivID);
  }
}
