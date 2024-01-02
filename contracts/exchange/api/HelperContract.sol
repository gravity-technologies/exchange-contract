// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../util/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract HelperContract is ReentrancyGuard {
  State internal state;

  // eip712domainTypehash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  // precomputed value for keccak256(abi.encode(eip712domainTypehash, keccak256(bytes("GRVTEx")), keccak256(bytes("0")), 0, address(0)));
  bytes32 private constant DOMAIN_HASH = bytes32(0x3872804bea0616a4202203552aedc3568e0a2ec586cd6ebbef3dec4e3bd471dd);

  /// @dev set the system timestamp and last transactionID.
  /// Require that the timestamp is monotonic, and the transactionID to be in sequence without any gap
  function _setSequence(int64 timestamp, uint64 txID) internal {
    require(timestamp > state.timestamp, "invalid timestamp");
    require(txID == state.lastTxID + 1, "invalid txID");
    state.timestamp = timestamp;
    state.lastTxID = txID;
  }

  function _requireAccount(address accID) internal view returns (Account storage) {
    Account storage acc = state.accounts[accID];
    require(acc.id != address(0), "account does not exist");
    return acc;
  }

  function _requireSubAccount(uint64 subAccID) internal view returns (SubAccount storage) {
    SubAccount storage sub = state.subAccounts[subAccID];
    require(sub.id != 0, "subaccount does not exist");
    return sub;
  }

  // Verify that the signatures are from the list of eligible signers, and those signatures form a simple majority
  function _requireSignatureQuorum(
    mapping(address => uint64) storage eligibleSigners,
    uint quorum,
    bytes32 hash,
    Signature[] calldata sigs
  ) internal {
    // FIXME: implement
    uint numSigs = sigs.length;
    // 1. Check that there are no duplicate signing key in the signatures
    for (uint i = 0; i < numSigs; i++)
      for (uint j = i + 1; j < numSigs; j++) {
        require(sigs[i].signer != sigs[j].signer, "duplicate signing key");
      }

    // 2. Check that the signatures form a quorum
    // require(numSigs >= quorum, "failed quorum");

    // 3. Check that the payload hash was not executed before
    require(!state.replay.executed[hash], "invalid transaction");

    // 4. Check that the signatures are valid and from the list of eligible signers
    int64 timestamp = state.timestamp;
    for (uint i = 0; i < numSigs; i++) {
      // TODO: require(addressExists(eligibleSigners, sigs[i].signer), "ineligible signer");
      _requireValidSig(timestamp, hash, sigs[i]);
    }

    // 5. Mark the payload hash as executed, to prevent replay attack
    state.replay.executed[hash] = true;
  }

  function _max(uint a, uint b) internal pure returns (uint) {
    return a >= b ? a : b;
  }

  /// @dev Verify that a signature is valid with replay attack prevention
  /// To understand why require the payload hash to be unique, and not the signature, read
  /// https://github.com/kadenzipfel/smart-contract-vulnerabilities/blob/master/vulnerabilities/signature-malleability.md
  function _preventReplay(bytes32 hash, Signature calldata sig) internal {
    require(!state.replay.executed[hash], "replayed payload");
    _requireValidSig(state.timestamp, hash, sig);
    state.replay.executed[hash] = true;
  }

  // Verify that a signature is valid. Caller need to prevent replay attack
  function _requireValidSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal pure {
    require(sig.expiration > 0 && sig.expiration > timestamp, "expired");
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_HASH, hash));
    (address addr, ECDSA.RecoverError err, ) = ECDSA.tryRecover(digest, sig.v, sig.r, sig.s);
    require(err == ECDSA.RecoverError.NoError && addr == sig.signer, "invalid signature");
  }

  // Check if the caller has certain permissions on a subaccount
  function _requirePermission(SubAccount storage sub, address signer, uint64 requiredPerm) internal view {
    Account storage acc = _requireAccount(sub.accountID);
    if (signerHasPerm(acc.signers, signer, AccountPermAdmin)) return;
    uint64 signerAuthz = sub.signers[signer];
    require(signerAuthz & (SubAccountPermAdmin | requiredPerm) > 0, "no permission");
  }
}
