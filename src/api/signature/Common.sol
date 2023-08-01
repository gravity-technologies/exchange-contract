// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Signature} from "../../DataStructure.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

struct EIP712Domain {
  string name;
  string version;
  uint256 chainId;
  address verifyingContract;
}

// prettier-ignore
bytes32 constant eip712domainTypehash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
// prettier-ignore
bytes32 constant domainHash = keccak256( abi.encode(eip712domainTypehash, keccak256(bytes("GRVTEx")), keccak256(bytes("0")), 0, address(0)));

function verify(
  mapping(bytes32 => bool) storage isExecuted,
  uint64 timestamp,
  bytes32 payloadHash,
  Signature calldata sig
) {
  require(sig.expiration > 0 && sig.expiration > timestamp, "expired");
  require(!isExecuted[payloadHash], "invalid transaction");
  isExecuted[payloadHash] = true;
  bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainHash, payloadHash));
  (address signerAddr, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, sig.v, sig.r, sig.s);
  require(err == ECDSA.RecoverError.NoError && signerAddr == sig.signer, "invalid signature");
}
