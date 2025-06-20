pragma solidity ^0.8.20;

import "./api/AccountContract.sol";
import "./api/SubAccountContract.sol";
import "./api/WalletRecoveryContract.sol";
import "./api/OracleContract.sol";
import "./api/CurrencyContract.sol";
import "./api/TransferContract.sol";
import "./api/AssertionContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GRVTExchangeTest is
  Initializable,
  CurrencyContract,
  AccountContract,
  SubAccountContract,
  WalletRecoveryContract,
  OracleContract,
  TransferContract,
  AssertionContract
{
  using BIMath for BI;

  function initialize(
    address admin,
    address chainSubmitter,
    address initializeConfigSigner,
    address beaconOwner,
    bytes32 depositProxyProxyBytecodeHash
  ) public initializer {
    __ReentrancyGuard_init();

    // Initialize the config timelock rules
    _setDefaultConfigSettings();
    state.initializeConfigSigner = initializeConfigSigner;

    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _setupRole(CHAIN_SUBMITTER_ROLE, chainSubmitter);

    address depositProxy = address(new DepositProxy{salt: bytes32(0)}());
    state.depositProxyBeacon = new UpgradeableBeacon{salt: bytes32(0)}(depositProxy);
    state.depositProxyBeacon.transferOwnership(beaconOwner);
    state.depositProxyProxyBytecodeHash = depositProxyProxyBytecodeHash;
  }

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

  function isAllAccountExists(address[] calldata accountIDs) public view returns (bool) {
    for (uint256 i = 0; i < accountIDs.length; i++) {
      if (state.accounts[accountIDs[i]].id == address(0)) {
        return false;
      }
    }
    return true;
  }

  function getAccountSpotBalance(address accID, Currency currency) public view returns (int64) {
    Account storage account = state.accounts[accID];
    return account.spotBalances[currency];
  }

  function isRecoveryAddress(address id, address signer, address recoveryAddress) public view returns (bool) {
    Account storage account = state.accounts[id];
    return addressExists(account.recoveryAddresses[signer], recoveryAddress);
  }

  function isOnboardedWithdrawalAddress(address id, address withdrawalAddress) public view returns (bool) {
    Account storage account = state.accounts[id];
    return account.onboardedWithdrawalAddresses[withdrawalAddress];
  }

  function getAccountOnboardedTransferAccount(address accID, address transferAccount) public view returns (bool) {
    Account storage account = state.accounts[accID];
    return account.onboardedTransferAccounts[transferAccount];
  }

  function getSignerPermission(address id, address signer) public view returns (uint64) {
    Account storage account = state.accounts[id];
    return account.signers[signer];
  }

  function getSessionValue(address sessionKey) public view returns (address, int64) {
    return (state.sessions[sessionKey].subAccountSigner, state.sessions[sessionKey].expiry);
  }

  function getConfig2D(ConfigID id, bytes32 subKey) public view returns (bytes32) {
    ConfigValue storage config = state.config2DValues[id][subKey];
    if (config.isSet) {
      return config.val;
    }
    return state.config2DValues[id][DEFAULT_CONFIG_ENTRY].val;
  }

  function config1DIsSet(ConfigID id) public view returns (bool) {
    return state.config1DValues[id].isSet;
  }

  function config2DIsSet(ConfigID id) public view returns (bool) {
    return state.config2DValues[id][DEFAULT_CONFIG_ENTRY].isSet;
  }

  function getConfig1D(ConfigID id) public view returns (bytes32) {
    return state.config1DValues[id].val;
  }

  function getConfigSchedule(ConfigID id, bytes32 subKey) public view returns (int64) {
    return state.configSettings[id].schedules[subKey].lockEndTime;
  }

  function isConfigScheduleAbsent(ConfigID id, bytes32 subKey) public view returns (bool) {
    return state.configSettings[id].schedules[subKey].lockEndTime == 0;
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

  function getSubAccSignerPermission(uint64 id, address signer) public view returns (uint64) {
    SubAccount storage subAccount = state.subAccounts[id];
    return subAccount.signers[signer];
  }

  function getFundingIndex(bytes32 assetID) public view returns (int64) {
    return state.prices.fundingIndex[assetID];
  }

  function getFundingTime() public view returns (int64) {
    return state.prices.fundingTime;
  }

  function getMarkPrice(bytes32 assetID) public view returns (uint64, bool) {
    return _getAssetPrice9Dec(assetID);
  }

  function getSettlementPrice(bytes32 assetID) public view returns (uint64, bool) {
    SettlementPriceEntry storage entry = state.prices.settlement[assetID];
    return (entry.value, entry.isSet);
  }

  function getInterestRate(bytes32 assetID) public view returns (int32) {
    return state.prices.interest[assetID];
  }

  function getSubAccountValue(uint64 subAccountID) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    uint64 quoteDecimals = _getBalanceDecimal(sub.quoteCurrency);
    return _getSubAccountValueInQuote(sub).toInt64(quoteDecimals);
  }

  function getSubAccountPosition(
    uint64 subAccountID,
    bytes32 assetID
  ) public view returns (bool found, int64 balance, int64 lastAppliedFundingIndex) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(assetID));
    Position storage pos = posmap.values[assetID];
    return (pos.id != 0x0, pos.balance, pos.lastAppliedFundingIndex);
  }

  function getSubAccountPositionCount(uint64 subAccountID) public view returns (uint) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.perps.keys.length + sub.futures.keys.length + sub.options.keys.length;
  }

  function getSubAccountSpotBalance(uint64 subAccountID, Currency currency) public view returns (int64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return sub.spotBalances[currency];
  }

  function getSimpleCrossMaintenanceMarginTiers(bytes32 kuq) public view returns (MarginTier[] memory) {
    uint64 qDec = _getBalanceDecimal(assetGetQuote(kuq));
    ListMarginTiersBI memory tiers = _getListMarginTiersBIFromStorage(kuq);
    MarginTier[] memory result = new MarginTier[](tiers.tiers.length);
    for (uint i = 0; i < tiers.tiers.length; i++) {
      result[i] = MarginTier({
        bracketStart: tiers.tiers[i].bracketStart.toUint64(qDec),
        rate: SafeCast.toUint32(SafeCast.toUint256(tiers.tiers[i].rate.toInt256(CENTIBEEP_DECIMALS)))
      });
    }
    return result;
  }

  function getSimpleCrossMaintenanceMarginTimelockEndTime(bytes32 kuq) public view returns (int64) {
    return state.simpleCrossMaintenanceMarginTimelockEndTime[kuq];
  }

  function getSubAccountMaintenanceMargin(uint64 subAccountID) public view returns (uint64) {
    SubAccount storage sub = _requireSubAccount(subAccountID);
    return _getMaintenanceMargin(sub);
  }

  function getTimestamp() public view returns (int64) {
    return state.timestamp;
  }

  function getExchangeCurrencyBalance(Currency currency) public view returns (int64) {
    return state.totalSpotBalances[currency];
  }

  function getInsuranceFundLoss(Currency currency) public view returns (int64) {
    require(currency == Currency.USDT, "Invalid currency");
    return _getInsuranceFundLossAmountUSDT();
  }

  function getTotalClientEquity(Currency currency) public view returns (int64) {
    require(currency == Currency.USDT, "Invalid currency");
    return _getTotalClientValueUSDT();
  }

  function isUnderDeriskMargin(uint64 subAccountID, bool underDeriskMargin) public view returns (bool) {
    SubAccount storage sub = _requireSubAccount(subAccountID);

    // Compute the maintenance margin
    uint64 mm = _getMaintenanceMargin(sub);
    uint64 qDec = _getBalanceDecimal(sub.quoteCurrency);
    BI memory mmBI = BI(SafeCast.toInt256(uint(mm)), qDec);

    // Compute the derisk margin
    // TODO: if subAccount is vault, ratio = DERISK_MM_RATIO_VAULT
    uint64 ratio = sub.deriskToMaintenanceMarginRatio == 0
      ? DERISK_MM_RATIO_DEFAULT
      : sub.deriskToMaintenanceMarginRatio;
    BI memory ratioBI = BI(int64(ratio), DERISK_RATIO_DECIMALS);
    uint64 deriskMargin = mmBI.mul(ratioBI).toUint64(qDec);

    BI memory totalEquityBI = _getSubAccountValueInQuote(sub);
    int64 totalEquity = totalEquityBI.toInt64(qDec);

    if (underDeriskMargin) {
      return totalEquity < int64(deriskMargin);
    } else {
      return totalEquity >= int64(deriskMargin);
    }
  }

  function getCurrencyDecimals(uint16 id) public view returns (uint16) {
    return state.currencyConfigs[id].balanceDecimals;
  }
}
