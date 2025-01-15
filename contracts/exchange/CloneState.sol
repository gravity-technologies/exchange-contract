pragma solidity ^0.8.20;

import "./api/BaseContract.sol";
import "./api/MarginConfigContract.sol";

struct CSpot {
  Currency currency;
  int64 balance;
}

struct CConfig {
  ConfigID id;
  bytes32 value;
}

struct CConfig2D {
  ConfigID id;
  bytes32 subKey;
  bytes32 value;
}

struct CConfigSchedule {
  ConfigID id;
  bytes32 subKey;
  int64 lockEndTime;
}

struct CMarginTiers {
  bytes32 kuq;
  int64 lockEndTime;
  MarginTier[] tiers;
}

struct CSession {
  address sessionKey;
  address subAccountSigner;
  int64 expiry;
}

struct COrderState {
  bytes32 orderID;
  bytes32 assetID;
  uint64 size;
}

struct CMarkPrice {
  bytes32 assetID;
  uint64 price;
}

struct CFundingIndex {
  bytes32 assetID;
  int64 fundingIndex;
}

struct CTotalSpotBalance {
  Currency currency;
  int64 balance;
}

struct CSigner {
  address addr;
  uint64 permission;
}

struct CRecoveryAddress {
  address id;
  address[] recoveryAddresses;
}

struct CAccount {
  address id;
  uint64 multiSigThreshold;
  uint64 adminCount;
  CSpot[] spotBalances;
  address[] onboardedWithdrawalAddresses;
  address[] onboardedTransferAccounts;
  uint64[] subAccounts;
  CSigner[] signers;
  CRecoveryAddress[] recoveryAddresses;
}

struct CSubAccount {
  uint64 id;
  uint64 adminCount;
  uint64 signerCount;
  int64 lastAppliedFundingTimestamp;
  address accountID;
  MarginType marginType;
  Currency quoteCurrency;
  CSpot[] spotBalances;
  Position[] perps;
  CSigner[] signers;
}

// DEBUG-ONLY: This is a contract that is used to clone the offchain state machine
// Use case: to quickly replicate the state machine to debug state divergence
contract ClonseStateContract is BaseContract, MarginConfigContract {
  function copyBase(
    int64 timestamp,
    uint64 lastTxID,
    address initializeConfigSigner,
    uint configVersion,
    address[] calldata bridgingPartners
  ) external {
    state.timestamp = timestamp;
    state.lastTxID = lastTxID;
    state.initializeConfigSigner = initializeConfigSigner;
    state.configVersion = configVersion;
    state.bridgingPartners = bridgingPartners;
  }

  function copyConfig(
    CConfig[] calldata config1Ds,
    CConfig2D[] calldata config2Ds,
    CConfigSchedule[] calldata schedules
  ) external {
    for (uint i = 0; i < config1Ds.length; i++) {
      CConfig memory c = config1Ds[i];
      state.config1DValues[c.id] = ConfigValue({isSet: true, val: c.value});
    }
    for (uint i = 0; i < config2Ds.length; i++) {
      CConfig2D memory c = config2Ds[i];
      state.config2DValues[c.id][c.subKey] = ConfigValue({isSet: true, val: c.value});
    }
    for (uint i = 0; i < schedules.length; i++) {
      CConfigSchedule memory c = schedules[i];
      state.configSettings[c.id].schedules[c.subKey].lockEndTime = c.lockEndTime;
    }
  }

  function copyMarginTiers(bytes32 kuq, int64 lockEndTime, MarginTier[] calldata tiers) external {
    ListMarginTiersBI memory tiersBI = _convertToListMarginTiersBI(kuq, tiers);
    state.simpleCrossMaintenanceMarginTiers[kuq].kud = kuq;
    state.simpleCrossMaintenanceMarginTimelockEndTime[kuq] = lockEndTime;
    _setListMarginTiersBIToStorage(kuq, tiersBI);
  }

  function copyAccounts(CAccount[] calldata accs) external {
    for (uint i = 0; i < accs.length; i++) {
      copyAccount(accs[i]);
    }
  }

  function copyAccount(CAccount calldata inp) public {
    mapping(address => Account) storage accs = state.accounts;
    Account storage a = accs[inp.id];
    a.id = inp.id;
    a.multiSigThreshold = inp.multiSigThreshold;
    a.adminCount = inp.adminCount;
    a.subAccounts = inp.subAccounts;

    // copy spot balances
    for (uint i = 0; i < inp.spotBalances.length; i++) {
      CSpot calldata s = inp.spotBalances[i];
      a.spotBalances[s.currency] = s.balance;
    }

    // copy recovery addresses
    for (uint i = 0; i < inp.recoveryAddresses.length; i++) {
      CRecoveryAddress calldata r = inp.recoveryAddresses[i];
      for (uint j = 0; j < r.recoveryAddresses.length; j++) {
        a.recoveryAddresses[r.id].push(r.recoveryAddresses[j]);
      }
    }

    // copy withdrawal addresses
    for (uint i = 0; i < inp.onboardedWithdrawalAddresses.length; i++) {
      a.onboardedWithdrawalAddresses[inp.onboardedWithdrawalAddresses[i]] = true;
    }

    // copy transfer accounts
    for (uint i = 0; i < inp.onboardedTransferAccounts.length; i++) {
      a.onboardedTransferAccounts[inp.onboardedTransferAccounts[i]] = true;
    }

    // copy subaccounts
    for (uint i = 0; i < inp.subAccounts.length; i++) {
      a.subAccounts.push(inp.subAccounts[i]);
    }

    // copy signers
    for (uint i = 0; i < inp.signers.length; i++) {
      CSigner calldata s = inp.signers[i];
      a.signers[s.addr] = s.permission;
    }
  }

  function copySubAccounts(CSubAccount[] calldata subs) external {
    for (uint i = 0; i < subs.length; i++) {
      copySubAccount(subs[i]);
    }
  }

  function copySubAccount(CSubAccount calldata inp) private {
    mapping(uint64 => SubAccount) storage subs = state.subAccounts;
    SubAccount storage sub = subs[inp.id];
    sub.id = inp.id;
    sub.adminCount = inp.adminCount;
    sub.signerCount = inp.signerCount;
    sub.lastAppliedFundingTimestamp = inp.lastAppliedFundingTimestamp;
    sub.accountID = inp.accountID;
    sub.marginType = inp.marginType;
    sub.quoteCurrency = inp.quoteCurrency;

    // copy perp positions
    for (uint i = 0; i < inp.perps.length; i++) {
      Position calldata p = inp.perps[i];
      sub.perps.keys.push(p.id);
      sub.perps.values[p.id] = p;
      sub.perps.index[p.id] = i;
    }

    // copy spot balances
    for (uint i = 0; i < inp.spotBalances.length; i++) {
      CSpot calldata s = inp.spotBalances[i];
      sub.spotBalances[s.currency] = s.balance;
    }

    // copy signers
    for (uint i = 0; i < inp.signers.length; i++) {
      CSigner calldata s = inp.signers[i];
      sub.signers[s.addr] = s.permission;
    }
  }

  function copySessions(CSession[] calldata sessions) external {
    for (uint i = 0; i < sessions.length; i++) {
      CSession memory c = sessions[i];
      state.sessions[c.sessionKey] = Session({subAccountSigner: c.subAccountSigner, expiry: c.expiry});
    }
  }

  function copySigReplayState(bytes32[] calldata sigs) external {
    for (uint i = 0; i < sigs.length; i++) {
      state.replay.executed[sigs[i]] = true;
    }
  }

  function copyOrderState(COrderState[] calldata orderStates) external {
    for (uint i = 0; i < orderStates.length; i++) {
      COrderState calldata o = orderStates[i];
      state.replay.sizeMatched[o.orderID][o.assetID] = o.size;
    }
  }

  function copyMarkPrices(CMarkPrice[] calldata markPrices) external {
    for (uint i = 0; i < markPrices.length; i++) {
      CMarkPrice calldata m = markPrices[i];
      state.prices.mark[m.assetID] = m.price;
    }
  }

  function copyFundingState(int64 fundingTime, CFundingIndex[] calldata fundingIndices) external {
    state.prices.fundingTime = fundingTime;
    for (uint i = 0; i < fundingIndices.length; i++) {
      CFundingIndex calldata f = fundingIndices[i];
      state.prices.fundingIndex[f.assetID] = f.fundingIndex;
    }
  }

  function copyTotalSpotBalance(CTotalSpotBalance[] calldata totalSpotBalances) external {
    for (uint i = 0; i < totalSpotBalances.length; i++) {
      CTotalSpotBalance calldata t = totalSpotBalances[i];
      state.totalSpotBalances[t.currency] = t.balance;
    }
  }
}
