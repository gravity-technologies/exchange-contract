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
import {DepositProxy} from "../../DepositProxy.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {SystemContractsCaller} from "../../../lib/era-contracts/l2-contracts/contracts/SystemContractsCaller.sol";
import {L2ContractHelper, DEPLOYER_SYSTEM_CONTRACT, IContractDeployer} from "../../../lib/era-contracts/l2-contracts/contracts/L2ContractHelper.sol";

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

  function _requireAccountNoBalance(Account storage acc) internal view {
    for (Currency i = currencyStart(); currencyIsValid(i); i = currencyNext(i)) {
      require(!currencyCanHoldSpotBalance(i) || acc.spotBalances[i] == 0, "account has balance");
    }
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

  function getDepositProxyBytecodeHash() public view returns (bytes32) {
    return state.depositProxyProxyBytecodeHash;
  }

  function getDepositProxyBeacon() public view returns (address) {
    return address(state.depositProxyBeacon);
  }

  function _getBalanceDecimal(Currency currency) internal pure returns (uint64) {
    uint64 decimals;
    if (
      currency == Currency.BTC ||
      currency == Currency.ETH ||
      currency == Currency.SOL ||
      currency == Currency.BNB ||
      currency == Currency.AAVE
    ) {
      decimals = 9;
    } else if (
      currency == Currency.USD ||
      currency == Currency.USDC ||
      currency == Currency.USDT ||
      currency == Currency.ARB ||
      currency == Currency.ZK ||
      currency == Currency.POL ||
      currency == Currency.OP ||
      currency == Currency.ATOM ||
      currency == Currency.TON ||
      currency == Currency.XRP ||
      currency == Currency.XLM ||
      currency == Currency.WLD ||
      currency == Currency.WIF ||
      currency == Currency.VIRTUAL ||
      currency == Currency.TRUMP ||
      currency == Currency.SUI ||
      currency == Currency.KSHIB ||
      currency == Currency.POPCAT ||
      currency == Currency.PENGU ||
      currency == Currency.LINK ||
      currency == Currency.KBONK ||
      currency == Currency.JUP ||
      currency == Currency.FARTCOIN ||
      currency == Currency.ENA ||
      currency == Currency.DOGE ||
      currency == Currency.AIXBT ||
      currency == Currency.AI_16_Z ||
      currency == Currency.ADA ||
      currency == Currency.BERA ||
      currency == Currency.VINE ||
      currency == Currency.PENDLE ||
      currency == Currency.UXLINK
    ) {
      decimals = 6;
    } else if (currency == Currency.KPEPE) {
      decimals = 3;
    } else {
      revert(ERR_UNSUPPORTED_CURRENCY);
    }

    return decimals;
  }

  function _getBalanceMultiplier(Currency currency) internal pure returns (uint64) {
    return uint64(10) ** _getBalanceDecimal(currency);
  }

  function _requireAssetPriceBI(bytes32 assetID) internal view returns (BI memory) {
    (uint64 markPrice, bool found) = _getAssetPrice9Dec(assetID);
    require(found, "mark price not found");
    return BI(int256(uint256(markPrice)), PRICE_DECIMALS);
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

  function _convertCurrency(BI memory amount, Currency from, Currency to) internal view returns (BI memory) {
    return amount.mul(_getSpotPriceInQuote(from, to)).scale(_getBalanceDecimal(to));
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

  /**
   * @dev Deploys a new deposit proxy contract for a specific main account. To be called at account creation.
   * @param account The account address to deploy the deposit proxy for
   * @return The address of the newly deployed deposit proxy contract
   * @notice This function:
   * 1. Deploys a new beacon proxy contract as a beacon proxy with CREATE2
   * 2. Initializes the proxy with the exchange contract address and account
   */
  function _deployDepositProxy(address account) internal returns (address) {
    bytes32 salt = _getCreate2Salt(account);

    address depositProxy = _deployBeaconProxy(salt);
    DepositProxy(depositProxy).initialize(address(this), account);

    return depositProxy;
  }

  function _getCreate2Salt(address accountID) internal pure returns (bytes32 salt) {
    salt = bytes32(uint256(uint160(accountID)));
  }

  /**
   * @dev Deploys a new beacon proxy contract using the system contract caller
   * @param salt The CREATE2 salt used to determine the deployment address
   * @return proxy The address of the newly deployed beacon proxy contract
   * @notice This function deploys a proxy that points to the deposit proxy beacon with CREATE2
   * @custom:security The deployment uses the zkSync Era system contract caller which:
   * - Maintains deterministic addressing via CREATE2
   * - Uses beacon proxy bytecode hash with bytecode already registered with the chain
   * @custom:error Reverts if:
   * - System call fails to deploy the contract
   */
  function _deployBeaconProxy(bytes32 salt) internal returns (address proxy) {
    (bool success, bytes memory returndata) = SystemContractsCaller.systemCallWithReturndata(
      uint32(gasleft()),
      DEPLOYER_SYSTEM_CONTRACT,
      0,
      abi.encodeCall(
        IContractDeployer.create2,
        (salt, state.depositProxyProxyBytecodeHash, abi.encode(address(state.depositProxyBeacon), ""))
      )
    );

    // The deployment should be successful and return the address of the proxy
    require(success, "failed to deploy deposit proxy");
    proxy = abi.decode(returndata, (address));
  }

  function getDepositProxy(address accountID) public view returns (DepositProxy) {
    bytes32 constructorInputHash = keccak256(abi.encode(getDepositProxyBeacon(), ""));
    bytes32 salt = _getCreate2Salt(accountID);
    return
      DepositProxy(
        L2ContractHelper.computeCreate2Address(address(this), salt, getDepositProxyBytecodeHash(), constructorInputHash)
      );
  }

  function _getTotalAccountValueUSDT(Account storage account) internal view returns (BI memory) {
    uint dec = _getBalanceDecimal(Currency.USDT);

    BI memory totalValue = _getBalanceValueInQuoteCurrencyBI(account.spotBalances, Currency.USDT);

    for (uint256 i; i < account.subAccounts.length; ++i) {
      SubAccount storage subAcc = _requireSubAccount(account.subAccounts[i]);
      BI memory subValueInQuote = _getSubAccountValueInQuote(subAcc);
      BI memory subValueInUSDT = _convertCurrency(subValueInQuote, subAcc.quoteCurrency, Currency.USDT);

      totalValue = totalValue.add(subValueInUSDT);
    }

    return totalValue;
  }

  function _getBalanceValueInQuoteCurrencyBI(
    mapping(Currency => int64) storage balances,
    Currency quoteCurrency
  ) internal view returns (BI memory) {
    BI memory total = BIMath.zero();
    for (Currency i = currencyStart(); currencyIsValid(i); i = currencyNext(i)) {
      if (!currencyCanHoldSpotBalance(i)) {
        continue;
      }

      int64 balance = balances[i];
      if (balance == 0) {
        continue;
      }
      BI memory balanceBI = BI(balance, _getBalanceDecimal(quoteCurrency));
      BI memory balanceValueInQuote = _convertCurrency(balanceBI, i, quoteCurrency);
      total = total.add(balanceValueInQuote);
    }
    return total;
  }

  /// @dev Get the total value of a sub account in quote currency
  function _getSubAccountValueInQuote(SubAccount storage sub) internal view returns (BI memory) {
    BI memory totalValue = _getPositionsValueInQuote(sub.perps).add(_getPositionsValueInQuote(sub.futures)).add(
      _getPositionsValueInQuote(sub.options)
    );

    totalValue = totalValue.add(_getBalanceValueInQuoteCurrencyBI(sub.spotBalances, sub.quoteCurrency));

    return totalValue;
  }

  /// @dev Get the total value of a position collections in quote currency
  function _getPositionsValueInQuote(PositionsMap storage positions) internal view returns (BI memory) {
    BI memory total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      bytes32 assetID = pos.id;
      Currency underlying = assetGetUnderlying(assetID);
      uint64 uDec = _getBalanceDecimal(underlying);
      BI memory balance = BI(pos.balance, uDec);
      BI memory assetPrice = _requireAssetPriceBI(assetID);
      total = total.add(balance.mul(assetPrice));
    }
    return total;
  }
}
