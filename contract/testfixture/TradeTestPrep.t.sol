// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../GRVTExchange.sol";

// import "hardhat/console.sol";

contract TradeTestPrep is GRVTExchange {
  uint32 takerAccID = 1;
  address takerAddr = 0x41D076018Cd4744C388421F3fE4477Ca361a318F; // ac209314b7e995b30103d39aa4f2f7adf16c82acf15891ba45965eafd00e84df

  uint32 makerAccID = 2;
  address makerAddr = 0x5A12ACF4aFE5e074Fbf1781eC264E3179e1250D3; // 4698d89b8bc50606f68abdff32443d418ac25eb1adc7d4ca195d77ab836a29ae

  uint32 feeAccID = 999;
  address feeAddr = 0x5034fDb1387Ae20Ea2614e323666E863cbE363a8; // 0x7c4978a1147256ecd75161c96fc40fb08a26672fbb9497b2505ec873cdf9e6e8

  uint256 assetID = 0x1234;

  constructor(bytes32[] memory _initialConfig) GRVTExchange(_initialConfig) {
    // Setup Fee position
    initSubAccount(feeAddr, feeAccID, feeAddr);

    // Setup 2 accounts
    initSubAccount(takerAddr, takerAccID, takerAddr);
    SubAccount storage takerSub = _requireSubAccount(takerAddr);
    takerSub.balanceE9 += 10000000;

    initSubAccount(makerAddr, makerAccID, makerAddr);
    SubAccount storage makerSub = _requireSubAccount(makerAddr);
    makerSub.balanceE9 += 10000000;

    // Setup derivative price
    state.prices.assets[assetID] = 1000; // Finalise price/balance representation
  }

  function trade(uint64 timestamp, uint64 txID, Trade calldata t) external {
    derivativeTrade(timestamp, txID, t);
    // console.log("taker");
    _reportSub(takerAddr);
    // console.log("maker");
    _reportSub(takerAddr);
    // console.log("fee");
    _reportSub(_getAddressCfg(CfgID.FEE_SUB_ACCOUNT_ID));
  }

  function _reportSub(address subID) private view {
    // SubAccount storage sub = _requireSubAccount(subID);
    // console.logInt(sub.balance);
  }

  function initSubAccount(address adminAddress, uint32 accID, address subID) private {
    Account storage acc = state.accounts[accID];
    SubAccount storage sub = state.subAccounts[subID];
    // Create subaccount
    sub.id = subID;
    sub.accountID = accID;
    sub.marginType = MarginType.PORTFOLIO_CROSS_MARGIN;
    sub.quoteCurrency = Currency.USDT;
    // We will not create any authorizedSigners in subAccount upon creation.
    // All account admins are presumably authorizedSigners

    // Create a new account if one did not exist
    acc.id = accID;
    acc.multiSigThreshold = 1;
    // the first account admins is the signer of the first signature
    acc.admins.push(adminAddress);
    acc.subAccounts.push(subID);
  }
}
