// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../util/Address.sol";
import "../util/Asset.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract BaseContract is ReentrancyGuardUpgradeable {
  State internal state;

  // eip712domainTypehash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
  // precomputed value for keccak256(abi.encode(eip712domainTypehash, keccak256(bytes("GRVTEx")), keccak256(bytes("0")), 0, address(0)));
  bytes32 private constant DOMAIN_HASH = bytes32(0x3872804bea0616a4202203552aedc3568e0a2ec586cd6ebbef3dec4e3bd471dd);
  bytes private constant PREFIXED_DOMAIN_HASH = abi.encodePacked("\x19\x01", DOMAIN_HASH);

  /// @dev set the system timestamp and last transactionID.
  /// Require that the timestamp is monotonic, and the transactionID to be in sequence without any gap
  function _setSequence(int64 timestamp, uint64 txID) internal {
    require(timestamp >= state.timestamp, "invalid timestamp");
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

  /// @notice Checks if a signer has a permissions in an account or associated subaccounts
  /// @param acc The account
  /// @param signer The signer's address
  function _requireSignerInAccount(Account storage acc, address signer) internal view {
    if (acc.signers[signer] != 0) {
      return;
    }
    bool isSubAccSigner = false;
    uint256 numSubAccs = acc.subAccounts.length;
    for (uint256 i; i < numSubAccs; ++i) {
      SubAccount storage subAcc = _requireSubAccount(acc.subAccounts[i]);
      if (subAcc.signers[signer] != 0) {
        isSubAccSigner = true;
        break;
      }
    }
    require(isSubAccSigner, "signer not tagged to account");
  }

  // Verify that the signatures are from the list of eligible signers, signer of each signature has admin permissions and those signatures form a simple majority
  function _requireSignatureQuorum(
    mapping(address => uint64) storage eligibleSigners,
    uint quorum,
    bytes32 hash,
    Signature[] calldata sigs
  ) internal {
    // FIXME: implement
    uint numSigs = sigs.length;
    // 1. Check that there are no duplicate signing key in the signatures
    for (uint i; i < numSigs; ++i) {
      for (uint j = i + 1; j < numSigs; ++j) {
        require(sigs[i].signer != sigs[j].signer, "duplicate signing key");
      }
    }

    // 2. Check that the signatures form a quorum
    require(numSigs >= quorum, "failed quorum");

    // 3. Check that the payload hash was not executed before
    require(!state.replay.executed[hash], "invalid transaction");

    // 4. Check that the signatures are valid and from the list of eligible signers
    int64 timestamp = state.timestamp;
    for (uint i; i < numSigs; ++i) {
      require(signerHasPerm(eligibleSigners, sigs[i].signer, AccountPermAdmin), "ineligible signer");
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
    require(sig.expiration > 0 && sig.expiration >= timestamp, "expired");
    _requireValidNoExipry(hash, sig);
  }

  function _requireValidNoExipry(bytes32 hash, Signature calldata sig) internal pure {
    bytes32 digest = keccak256(abi.encodePacked(PREFIXED_DOMAIN_HASH, hash));
    (address addr, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, sig.v, sig.r, sig.s);
    require(err == ECDSA.RecoverError.NoError && addr == sig.signer, "invalid signature");
  }

  // Check if the signer has certain permissions on a subaccount
  function _requireSubAccountPermission(SubAccount storage sub, address signer, uint64 requiredPerm) internal view {
    Account storage acc = _requireAccount(sub.accountID);
    if (signerHasPerm(acc.signers, signer, AccountPermAdmin)) return;
    uint64 signerAuthz = sub.signers[signer];
    require(signerAuthz & (SubAccountPermAdmin | requiredPerm) > 0, "no permission");
  }

  // Check if the signer has certain permissions on an account
  function _requireAccountPermission(Account storage account, address signer, uint64 requiredPerm) internal view {
    require(account.signers[signer] & (AccountPermAdmin | requiredPerm) > 0, "no permission");
  }

  // Check if the caller has certain permissions on a subaccount
  function getLastTxID() external view returns (uint64) {
    return state.lastTxID;
  }

  function _getBalanceDecimal(Currency currency) internal pure returns (uint64) {
    uint idx = uint(currency);

    require(idx != 0, ERR_UNSUPPORTED_CURRENCY);

    // USDT, USDC, USD
    if (idx < 4) return 6;

    // ETH, BTC
    return 9;
  }

  // Price utils
  function _getMarkPrice9Decimals(bytes32 assetID) internal view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);

    // If spot, process separately
    if (kind == Kind.SPOT) {
      return _getQuoteMarkPrice9Decimals(assetGetUnderlying(assetID));
    }

    Currency quote = assetGetQuote(assetID);
    // Only derivatives remaining
    (uint64 underlyingPrice, bool found) = _getUnderlyingMarkPrice9Decimals(assetID);
    if (!found) {
      return (0, false);
    }

    // If getting price in USD, we can simply scale and return
    if (quote == Currency.USD) {
      return (underlyingPrice, true);
    }

    // Otherwise, we have to convert to USDT/USDC price
    (uint64 quotePrice, bool quoteFound) = _getQuoteMarkPrice9Decimals(quote);
    if (!quoteFound) {
      return (0, false);
    }

    return (uint64((uint(underlyingPrice) * (10 ** PRICE_DECIMALS)) / uint(quotePrice)), true);
  }

  function _getUnderlyingMarkPrice9Decimals(bytes32 assetID) internal view returns (uint64, bool) {
    uint64 price = state.prices.mark[assetSetQuote(assetID, Currency.USD)];
    return (price, price != 0);
  }

  function _getQuoteMarkPrice9Decimals(Currency currency) internal view returns (uint64, bool) {
    uint64 price = state.prices.mark[_getSpotAssetID(currency)];
    return (price, price != 0);
  }

  function _getSpotAssetID(Currency currency) internal pure returns (bytes32) {
    return
      assetToID(
        Asset({kind: Kind.SPOT, underlying: currency, quote: Currency.UNSPECIFIED, expiration: 0, strikePrice: 0})
      );
  }
}
