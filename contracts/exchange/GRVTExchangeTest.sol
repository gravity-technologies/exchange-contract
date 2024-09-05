// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./GRVTExchange.sol";
import "./util/BIMath.sol";

contract GRVTExchangeTest is GRVTExchange {
  using BIMath for BI;

  struct AccountResult {
    address id;
    uint64 multiSigThreshold;
    uint64 adminCount;
    uint64[] subAccounts;
    // Not returned fields since mapping is not supported in return type include:
    // 1. spotBalances
    // 2. recoveryAddresses
    // 3. onboardedWithdrawalAddresses
    // 4. onboardedTransferAccounts
    // 5. signers
  }

  struct SubAccountResult {
    uint64 id;
    uint64 adminCount;
    uint64 signerCount;
    address accountID;
    MarginType marginType;
    Currency quoteCurrency;
    int64 lastAppliedFundingTimestamp;
    // Not returned fields since mapping or stucts with nested mapping is not supported in return type include:// The total amount of base currency that the sub account possesses
    // 1. spotBalances
    // 2. PositionsMap options;
    // 3. PositionsMap futures;
    // 4. PositionsMap perps;
    // 5. mapping(bytes => uint256) positionIndex;
    // 6. signers;
  }

  function getAccountResult(address accID) public view returns (AccountResult memory) {
    Account storage account = state.accounts[accID];
    return
      AccountResult({
        id: account.id,
        multiSigThreshold: account.multiSigThreshold,
        adminCount: account.adminCount,
        subAccounts: account.subAccounts
      });
  }

  function getSubAccountResult(uint64 id) public view returns (SubAccountResult memory) {
    SubAccount storage subAccount = state.subAccounts[id];
    return
      SubAccountResult({
        id: subAccount.id,
        adminCount: subAccount.adminCount,
        signerCount: subAccount.signerCount,
        accountID: subAccount.accountID,
        marginType: subAccount.marginType,
        quoteCurrency: subAccount.quoteCurrency,
        lastAppliedFundingTimestamp: subAccount.lastAppliedFundingTimestamp
      });
  }
}
