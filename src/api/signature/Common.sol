// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Signature, State} from "../../DataStructure.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

// eip712domainTypehash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
// precomputed value for keccak256(abi.encode(eip712domainTypehash, keccak256(bytes("GRVTEx")), keccak256(bytes("0")), 0, address(0)));
bytes32 constant DOMAIN_HASH = bytes32(0x3872804bea0616a4202203552aedc3568e0a2ec586cd6ebbef3dec4e3bd471dd);

// Verify that a signature is valid with replay attack prevention
// To understand why require the payload hash to be unique, and not the signature, read
// https://github.com/kadenzipfel/smart-contract-vulnerabilities/blob/master/vulnerabilities/signature-malleability.md
function requireUniqSig(State storage state, bytes32 payloadHash, Signature calldata sig) {
  require(!state.signatures.isExecuted[payloadHash], "replayed payload");
  requireValidSig(state.timestamp, payloadHash, sig);
  state.signatures.isExecuted[payloadHash] = true;
}

// Verify that a signature is valid. Caller need to prevent replay attack

function requireValidSig(uint64 timestamp, bytes32 payloadHash, Signature calldata sig) pure {
  require(sig.expiration > 0 && sig.expiration > timestamp, "expired");
  bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_HASH, payloadHash));
  (address addr, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, sig.v, sig.r, sig.s);
  require(err == ECDSA.RecoverError.NoError && addr == sig.signer, "invalid signature");
}
