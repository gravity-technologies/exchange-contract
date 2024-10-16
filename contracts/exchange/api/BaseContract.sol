pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/Address.sol";
import "../common/Error.sol";
import "../util/BIMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract BaseContract is AccessControlUpgradeable, ReentrancyGuardUpgradeable {
  using BIMath for BI;

  State internal state;

  bytes32 public constant CHAIN_SUBMITTER_ROLE = keccak256("CHAIN_SUBMITTER_ROLE");

  /// @dev Check if the tx.origin has a specific role.
  /// This is applied to all exchange transaction functions.
  /// We use this custom modifier to check tx.origin instead of msg.sender
  /// as in onlyRole for these reasons:
  /// 1. we might submit exchange transactions through an intermediate contract, e.g. multicall
  /// 2. the wallet that has CHAIN_SUBMITTER_ROLE is a single-purpose wallet that
  ///    only submits transactions to the exchange contract, and we control all
  ///    contracts on the private L2. This means it's unlikely for the CHAIN_SUBMITTER_ROLE
  ///    to be tricked into submitting exchange transactions inadventently.
  modifier onlyTxOriginRole(bytes32 role) {
    _checkRole(role, tx.origin);
    _;
  }

  bytes32 private constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId)");
  /// @dev This value will be replaced with the chainID specified in hardhat.config.ts when compiling the contract
  bytes32 private immutable DOMAIN_HASH =
    keccak256(
      abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes("GRVT Exchange")), keccak256(bytes("0")), block.chainid)
    );

  int64 internal constant ONE_HOUR_NANOS = 60 * 60 * 1e9;

  /// @dev The maximum signature expiry time. Any signature with a longer expiry time will capped to this value
  int64 private constant MAX_SIG_EXPIRY = 30 * 24 * ONE_HOUR_NANOS;

  /// @dev set the system timestamp and last transactionID.
  /// Require that the timestamp is monotonic, and the transactionID to be in sequence without any gap
  function _setSequence(int64 timestamp, uint64 txID) internal {
    require(timestamp >= state.timestamp, "invalid timestamp");
    require(state.lastTxID != 0, "tx before initializeConfig");
    require(txID == state.lastTxID + 1, "invalid txID");
    state.timestamp = timestamp;
    state.lastTxID = txID;
  }

  function _setSequenceInitializeConfig(int64 timestamp, uint64 txID) internal {
    require(timestamp >= state.timestamp, "invalid timestamp");
    require(state.lastTxID == 0, "initializeConfig called after first tx");
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

  function _requireSubAccountUnderAccount(SubAccount storage subAcc, address accID) internal view {
    require(subAcc.accountID == accID, "sub account not under account");
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
    bytes32[] memory hashes,
    Signature[] calldata sigs
  ) internal {
    // FIXME: implement
    uint numSigs = sigs.length;
    require(numSigs == hashes.length, "invalid number of hashes");
    // 1. Check that there are no duplicate signing key in the signatures
    for (uint i; i < numSigs; ++i) {
      for (uint j = i + 1; j < numSigs; ++j) {
        require(sigs[i].signer != sigs[j].signer, "duplicate signing key");
      }
    }

    // 2. Check that the signatures form a quorum
    require(numSigs >= quorum, "failed quorum");

    // 3. Check that the payload hash was not executed before
    for (uint i; i < numSigs; ++i) {
      require(!state.replay.executed[hashes[i]], "invalid transaction");
    }

    // 4. Check that the signatures are valid and from the list of eligible signers
    int64 timestamp = state.timestamp;
    for (uint i; i < numSigs; ++i) {
      require(signerHasPerm(eligibleSigners, sigs[i].signer, AccountPermAdmin), "ineligible signer");
      _requireValidSig(timestamp, hashes[i], sigs[i]);
      state.replay.executed[hashes[i]] = true;
    }
  }

  function _min(int64 a, int64 b) internal pure returns (int64) {
    return a <= b ? a : b;
  }

  function _max(int64 a, int64 b) internal pure returns (int64) {
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
  function _requireValidSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal view {
    require(sig.expiration >= timestamp && sig.expiration <= (timestamp + MAX_SIG_EXPIRY), "expired");
    _requireValidNoExipry(hash, sig);
  }

  function _requireValidNoExipry(bytes32 hash, Signature calldata sig) internal view {
    bytes32 digest = keccak256(abi.encodePacked(abi.encodePacked("\x19\x01", DOMAIN_HASH), hash));
    (address addr, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, sig.v, sig.r, sig.s);
    require(err == ECDSA.RecoverError.NoError && addr == sig.signer, "invalid signature");
  }

  // Check if the signer has certain permissions on a subaccount
  function _requireSubAccountPermission(SubAccount storage sub, address signer, uint64 requiredPerm) internal view {
    require(hasSubAccountPermission(sub, signer, requiredPerm), "no permission");
  }

  function hasSubAccountPermission(
    SubAccount storage sub,
    address signer,
    uint64 requiredPerm
  ) internal view returns (bool) {
    Account storage acc = _requireAccount(sub.accountID);
    if (signerHasPerm(acc.signers, signer, AccountPermAdmin)) return true;
    uint64 signerAuthz = sub.signers[signer];
    return signerAuthz & (SubAccountPermAdmin | requiredPerm) > 0;
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
    if (currency == Currency.BTC || currency == Currency.ETH) {
      return 9;
    }

    // USDT, USDC, USD
    if (currency == Currency.USDT || currency == Currency.USDC || currency == Currency.USD) {
      return 6;
    }

    revert(ERR_UNSUPPORTED_CURRENCY);
  }

  function _getBalanceMultiplier(Currency currency) internal pure returns (uint64) {
    return uint64(10) ** _getBalanceDecimal(currency);
  }

  function _requireAssetPriceBI(bytes32 assetID) internal view returns (BI memory) {
    (uint64 markPrice, bool found) = _getAssetPrice9Dec(assetID);
    require(found, "mark price not found");
    return BI(int256(uint256(markPrice)), PRICE_DECIMALS);
  }

  function _requireAssetPriceInUsdBI(bytes32 assetID) internal view returns (BI memory) {
    bytes32 assetWithUSDQuote = assetSetQuote(assetID, Currency.USD);
    BI memory markPrice = _requireAssetPriceBI(assetWithUSDQuote);
    return markPrice;
  }

  // Price utils
  function _getAssetPrice9Dec(bytes32 assetID) internal view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);

    // If spot, process separately
    if (kind == Kind.SPOT) {
      return _getSpotPrice9Dec(assetGetUnderlying(assetID));
    }

    Currency quote = assetGetQuote(assetID);
    // Only derivatives remaining
    (uint64 underlyingPrice, bool found) = _getUnderlyingAssetPrice9Dec(assetID);
    if (!found) {
      return (0, false);
    }

    // If getting price in USD, we can simply scale and return
    if (quote == Currency.USD) {
      return (underlyingPrice, true);
    }

    // Otherwise, we have to convert to USDT/USDC price
    (uint64 quotePrice, bool quoteFound) = _getSpotPrice9Dec(quote);
    if (!quoteFound) {
      return (0, false);
    }

    return (SafeCast.toUint64((uint(underlyingPrice) * (PRICE_MULTIPLIER)) / uint(quotePrice)), true);
  }

  function _getIndexPrice9Dec(bytes32 assetID) internal view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);

    Currency underlying = assetGetUnderlying(assetID);
    Currency quote = assetGetQuote(assetID);

    // If spot, process separately
    if (kind == Kind.SPOT) {
      return _getSpotPrice9Dec(underlying);
    }

    (uint64 underlyingPrice, bool found) = _getSpotPrice9Dec(underlying);
    if (!found) {
      return (0, false);
    }

    (uint64 quotePrice, bool quoteFound) = _getSpotPrice9Dec(quote);
    if (!quoteFound) {
      return (0, false);
    }

    return (SafeCast.toUint64((uint(underlyingPrice) * (PRICE_MULTIPLIER)) / uint(quotePrice)), true);
  }

  function _getUnderlyingAssetPrice9Dec(bytes32 assetID) internal view returns (uint64, bool) {
    uint64 price = state.prices.mark[assetSetQuote(assetID, Currency.USD)];
    return (price, price != 0);
  }

  /// @dev Get the spot price of one currency in terms of another
  /// @param spot The currency to get the price for
  /// @param quote The quote currency
  /// @return The price of spot in terms of quote
  function _getSpotPriceInQuote(Currency spot, Currency quote) internal view returns (BI memory) {
    if (spot == quote) {
      return BI(int(PRICE_MULTIPLIER), PRICE_DECIMALS);
    }

    return _getSpotPriceBI(spot).div(_getSpotPriceBI(quote));
  }

  /// @dev Get the spot price of a currency in terms of USD
  /// @param spot The currency to get the price for
  /// @return The price of the currency in USD
  function _getSpotPriceBI(Currency spot) internal view returns (BI memory) {
    (uint64 price, bool ok) = _getSpotPrice9Dec(spot);
    require(ok, "mark price not found");
    return BI(int256(uint(price)), PRICE_DECIMALS);
  }

  /// @dev Get the spot price of a currency with 9 decimal places
  /// @param currency The currency to get the price for
  /// @return price The price of the currency, ok Whether the price was found
  function _getSpotPrice9Dec(Currency currency) internal view returns (uint64, bool) {
    uint64 price = state.prices.mark[_getSpotAssetID(currency)];
    return (price, price != 0);
  }

  function _getSpotAssetID(Currency currency) internal pure returns (bytes32) {
    return
      assetToID(
        Asset({kind: Kind.SPOT, underlying: currency, quote: Currency.UNSPECIFIED, expiration: 0, strikePrice: 0})
      );
  }

  function _getPositionCollection(SubAccount storage sub, Kind kind) internal view returns (PositionsMap storage) {
    if (kind == Kind.PERPS) return sub.perps;
    if (kind == Kind.FUTURES) return sub.futures;
    if (kind == Kind.CALL || kind == Kind.PUT) return sub.options;
    revert("invalid asset kind");
  }

  function _getOrCreatePosition(SubAccount storage sub, bytes32 assetID) internal returns (Position storage) {
    Kind kind = assetGetKind(assetID);
    PositionsMap storage posmap = _getPositionCollection(sub, kind);

    // If the position already exists, return it
    if (posmap.values[assetID].id != 0x0) {
      return posmap.values[assetID];
    }

    // Otherwise, create a new position
    Position storage pos = getOrNew(posmap, assetID);

    if (kind == Kind.PERPS) {
      // IMPT: Perpetual positions MUST have LastAppliedFundingIndex set to the current funding index
      // to avoid mis-calculation of funding payment (leads to improper accounting of on-chain assets)
      pos.lastAppliedFundingIndex = state.prices.fundingIndex[assetID];
    }

    return pos;
  }
}
