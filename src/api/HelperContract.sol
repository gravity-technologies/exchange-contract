// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {requireValidSig} from "../api/signature/Common.sol";
import {Account, Signature, State, SubAccount} from "../DataStructure.sol";
import {addressExists} from "../util/Address.sol";

abstract contract HelperContract {
  function _setTimestampAndTxID(State storage state, uint64 timestamp, uint64 txID) internal {
    require(timestamp > state.timestamp, "invalid timestamp");
    require(txID == state.lastTxID + 1, "invalid txID");
    state.timestamp = timestamp;
    state.lastTxID = txID;
  }

  function _requireAccount(State storage state, uint32 accID) internal view returns (Account storage) {
    Account storage acc = state.accounts[accID];
    require(acc.id > 0, "account does not exist");
    return acc;
  }

  function _requireSubAccount(State storage state, address subAccID) internal view returns (SubAccount storage) {
    SubAccount storage sub = state.subAccounts[subAccID];
    require(sub.id != address(0), "subaccount does not exist");
    return sub;
  }

  // Verify that the signatures are from the list of eligible signers, and those signatures form a simple majority
  function _requireSignatureQuorum(
    State storage state,
    address[] memory eligibleSigners,
    uint quorum,
    bytes32 hash,
    Signature[] calldata sigs
  ) internal {
    _requireUniqSigs(sigs);
    uint64 timestamp = state.timestamp;
    // If the account is new, the threshold is 0, but we still need at least 1 signature.
    require(sigs.length >= _max(quorum, 1), "failed quorum");
    require(!state.signatures.isExecuted[hash], "invalid transaction");
    for (uint i = 0; i < sigs.length; i++) {
      require(addressExists(eligibleSigners, sigs[i].signer), "ineligible signer");
      requireValidSig(timestamp, hash, sigs[i]);
    }
    state.signatures.isExecuted[hash] = true;
  }

  function _requireUniqSigs(Signature[] calldata sigs) internal pure {
    // check that there are no duplicate signing key in the signatures
    for (uint i = 0; i < sigs.length; i++)
      for (uint j = i + 1; j < sigs.length; j++) {
        require(sigs[i].signer != sigs[j].signer, "duplicate signing key");
      }
  }

  function _max(uint a, uint b) internal pure returns (uint) {
    return a >= b ? a : b;
  }
}
