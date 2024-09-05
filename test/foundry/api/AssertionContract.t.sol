// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/exchange/util/Asset.sol";
import "../../../contracts/exchange/api/AssertionContract.sol";
import "../../../contracts/exchange/types/PositionMap.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

// Mock contract to allow setting state for testing
contract MockAssertionContract is AssertionContract {
  function setAccount(AccountAssertion memory account) public {
    state.accounts[account.id].id = account.id;
    state.accounts[account.id].multiSigThreshold = account.multiSigThreshold;
    state.accounts[account.id].adminCount = account.adminCount;
    state.accounts[account.id].subAccounts = account.subAccounts;

    for (uint i = 0; i < account.spotBalances.length; i++) {
      state.accounts[account.id].spotBalances[account.spotBalances[i].currency] = account.spotBalances[i].balance;
    }

    for (uint i = 0; i < account.recoveryAddresses.length; i++) {
      state.accounts[account.id].recoveryAddresses[account.recoveryAddresses[i].signer] = account
        .recoveryAddresses[i]
        .recoveryAddresses;
    }

    for (uint i = 0; i < account.onboardedWithdrawalAddresses.length; i++) {
      state.accounts[account.id].onboardedWithdrawalAddresses[account.onboardedWithdrawalAddresses[i]] = true;
    }

    for (uint i = 0; i < account.onboardedTransferAccounts.length; i++) {
      state.accounts[account.id].onboardedTransferAccounts[account.onboardedTransferAccounts[i]] = true;
    }

    for (uint i = 0; i < account.signers.length; i++) {
      state.accounts[account.id].signers[account.signers[i].signer] = account.signers[i].permission;
    }
  }

  function setSubAccount(SubAccountAssertion memory subAccount) public {
    state.subAccounts[subAccount.id].id = subAccount.id;
    state.subAccounts[subAccount.id].adminCount = subAccount.adminCount;
    state.subAccounts[subAccount.id].signerCount = subAccount.signerCount;
    state.subAccounts[subAccount.id].accountID = subAccount.accountID;
    state.subAccounts[subAccount.id].marginType = subAccount.marginType;
    state.subAccounts[subAccount.id].quoteCurrency = subAccount.quoteCurrency;
    state.subAccounts[subAccount.id].lastAppliedFundingTimestamp = subAccount.lastAppliedFundingTimestamp;

    for (uint i = 0; i < subAccount.spotBalances.length; i++) {
      state.subAccounts[subAccount.id].spotBalances[subAccount.spotBalances[i].currency] = subAccount
        .spotBalances[i]
        .balance;
    }

    for (uint i = 0; i < subAccount.perps.length; i++) {
      Position storage position = getOrNew(state.subAccounts[subAccount.id].perps, subAccount.perps[i].id);
      position.id = subAccount.perps[i].id;
      position.balance = subAccount.perps[i].balance;
      position.lastAppliedFundingIndex = subAccount.perps[i].lastAppliedFundingIndex;
    }

    for (uint i = 0; i < subAccount.futures.length; i++) {
      Position storage position = getOrNew(state.subAccounts[subAccount.id].futures, subAccount.futures[i].id);
      position.id = subAccount.futures[i].id;
      position.balance = subAccount.futures[i].balance;
      position.lastAppliedFundingIndex = subAccount.futures[i].lastAppliedFundingIndex;
    }

    for (uint i = 0; i < subAccount.options.length; i++) {
      Position storage position = getOrNew(state.subAccounts[subAccount.id].options, subAccount.options[i].id);
      position.id = subAccount.options[i].id;
      position.balance = subAccount.options[i].balance;
      position.lastAppliedFundingIndex = subAccount.options[i].lastAppliedFundingIndex;
    }

    for (uint i = 0; i < subAccount.signers.length; i++) {
      state.subAccounts[subAccount.id].signers[subAccount.signers[i].signer] = subAccount.signers[i].permission;
    }
  }

  function setSession(address sessionKey, address signer, int64 expiry) public {
    state.sessions[sessionKey] = Session({subAccountSigner: signer, expiry: expiry});
  }

  function setConfig2DValue(ConfigID id, bytes32 subKey, ConfigValue memory value) public {
    state.config2DValues[id][subKey] = value;
  }

  function setConfig1DValue(ConfigID id, ConfigValue memory value) public {
    state.config1DValues[id] = value;
  }

  // Helper function to set a specific funding index
  function setFundingIndex(bytes32 assetID, int64 index) public {
    state.prices.fundingIndex[assetID] = index;
  }

  // Helper function to set a specific mark price
  function setMarkPrice(bytes32 assetID, uint64 price) public {
    state.prices.mark[assetID] = price;
  }

  // Helper function to set a specific settlement price
  function setSettlementPrice(bytes32 assetID, uint64 value, bool isSet) public {
    state.prices.settlement[assetID] = SettlementPriceEntry({value: value, isSet: isSet});
  }

  // Helper function to set a specific interest rate
  function setInterestRate(bytes32 assetID, int32 rate) public {
    state.prices.interest[assetID] = rate;
  }
}

contract AssertionContractTest is Test {
  MockAssertionContract assertionContract;
  address testAccount;
  uint64 testSubAccount;

  function setUp() public {
    assertionContract = new MockAssertionContract();
    testAccount = address(0x1234);
    testSubAccount = 1;
  }

  function testAssertIsAllAccountExists() public {
    address[] memory accounts = new address[](2);
    accounts[0] = testAccount;
    accounts[1] = address(0x5678);

    AccountAssertion memory account1 = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: new address[](0),
      signers: new SignerAssertion[](0)
    });
    AccountAssertion memory account2 = AccountAssertion({
      id: address(0x5678),
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: new address[](0),
      signers: new SignerAssertion[](0)
    });

    assertionContract.setAccount(account1);
    assertionContract.setAccount(account2);

    assertionContract.assertIsAllAccountExists(accounts, true);
  }

  function testAssertAccountSpotBalance() public {
    Currency currency = Currency.ETH;
    int64 expectedBalance = 1000;

    SpotBalanceAssertion[] memory spotBalances = new SpotBalanceAssertion[](1);
    spotBalances[0] = SpotBalanceAssertion({currency: currency, balance: expectedBalance});

    AccountAssertion memory account = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: spotBalances,
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: new address[](0),
      signers: new SignerAssertion[](0)
    });

    assertionContract.setAccount(account);

    assertionContract.assertAccountSpotBalance(testAccount, currency, expectedBalance);
  }

  function testAssertIsRecoveryAddress() public {
    address signer = address(0x9876);
    address recoveryAddress = address(0xABCD);
    RecoveryAddressAssertion[] memory recoveryAddresses = new RecoveryAddressAssertion[](1);
    recoveryAddresses[0] = RecoveryAddressAssertion({signer: signer, recoveryAddresses: new address[](1)});
    recoveryAddresses[0].recoveryAddresses[0] = recoveryAddress;

    AccountAssertion memory account = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: recoveryAddresses,
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: new address[](0),
      signers: new SignerAssertion[](0)
    });

    assertionContract.setAccount(account);

    assertionContract.assertIsRecoveryAddress(testAccount, signer, recoveryAddress, true);
  }

  function testAssertIsOnboardedWithdrawalAddress() public {
    address withdrawalAddress = address(0xABCD);

    address[] memory onboardedWithdrawalAddresses = new address[](1);
    onboardedWithdrawalAddresses[0] = withdrawalAddress;

    AccountAssertion memory account = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: onboardedWithdrawalAddresses,
      onboardedTransferAccounts: new address[](0),
      signers: new SignerAssertion[](0)
    });

    assertionContract.setAccount(account);

    assertionContract.assertIsOnboardedWithdrawalAddress(testAccount, withdrawalAddress, true);
  }

  function testAssertAccountOnboardedTransferAccount() public {
    address transferAccount = address(0xDEF0);

    address[] memory onboardedTransferAccounts = new address[](1);
    onboardedTransferAccounts[0] = transferAccount;

    AccountAssertion memory account = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: onboardedTransferAccounts,
      signers: new SignerAssertion[](0)
    });

    assertionContract.setAccount(account);

    assertionContract.assertAccountOnboardedTransferAccount(testAccount, transferAccount, true);
  }

  function testAssertSignerPermission() public {
    address signer = address(0xDEF0);
    uint64 expectedPermission = 2;

    SignerAssertion[] memory signers = new SignerAssertion[](1);
    signers[0] = SignerAssertion({signer: signer, permission: expectedPermission});

    AccountAssertion memory account = AccountAssertion({
      id: testAccount,
      multiSigThreshold: 1,
      adminCount: 1,
      subAccounts: new uint64[](0),
      spotBalances: new SpotBalanceAssertion[](0),
      recoveryAddresses: new RecoveryAddressAssertion[](0),
      onboardedWithdrawalAddresses: new address[](0),
      onboardedTransferAccounts: new address[](0),
      signers: signers
    });

    assertionContract.setAccount(account);

    assertionContract.assertSignerPermission(testAccount, signer, expectedPermission);
  }

  function testAssertSessionValue() public {
    address sessionKey = address(0xFEDC);
    address expectedSigner = address(0xCBA9);
    int64 expectedExpiry = 1234567890;

    assertionContract.setSession(sessionKey, expectedSigner, expectedExpiry);

    assertionContract.assertSessionValue(sessionKey, expectedSigner, expectedExpiry);
  }

  function testAssertConfig2D() public {
    ConfigID id = ConfigID.MAINTENANCE_MARGIN_TIER_01;
    bytes32 subKey = bytes32("test_subkey");
    bytes32 expectedValue = bytes32("test_value");

    ConfigValue memory configValue = ConfigValue({isSet: true, val: expectedValue});

    assertionContract.setConfig2DValue(id, subKey, configValue);

    assertionContract.assertConfig2D(id, subKey, expectedValue);
  }

  function testAssertConfig1DIsSet() public {
    ConfigID id = ConfigID.MAINTENANCE_MARGIN_TIER_01;

    ConfigValue memory configValue = ConfigValue({isSet: true, val: bytes32("test_value")});

    assertionContract.setConfig1DValue(id, configValue);

    assertionContract.assertConfig1DIsSet(id, true);
  }

  bytes32 internal constant DEFAULT_CONFIG_ENTRY = bytes32(uint256(0));

  function testAssertConfig2DIsSet() public {
    ConfigID id = ConfigID.MAINTENANCE_MARGIN_TIER_01;

    ConfigValue memory configValue = ConfigValue({isSet: true, val: bytes32("test_value")});

    assertionContract.setConfig2DValue(id, DEFAULT_CONFIG_ENTRY, configValue);

    assertionContract.assertConfig2DIsSet(id, true);
  }

  function testAssertConfig1D() public {
    ConfigID id = ConfigID.MAINTENANCE_MARGIN_TIER_01;
    bytes32 expectedValue = bytes32("test_value");

    ConfigValue memory configValue = ConfigValue({isSet: true, val: expectedValue});

    assertionContract.setConfig1DValue(id, configValue);

    assertionContract.assertConfig1D(id, expectedValue);
  }

  function testAssertSubAccSignerPermission() public {
    address signer = address(0xDEF0);
    uint64 expectedPermission = 2;

    SignerAssertion[] memory signers = new SignerAssertion[](1);
    signers[0] = SignerAssertion({signer: signer, permission: expectedPermission});

    SubAccountAssertion memory subAccount = SubAccountAssertion({
      id: testSubAccount,
      adminCount: 1,
      signerCount: 1,
      accountID: testAccount,
      marginType: MarginType.SIMPLE_CROSS_MARGIN,
      quoteCurrency: Currency.USDC,
      lastAppliedFundingTimestamp: 0,
      spotBalances: new SpotBalanceAssertion[](0),
      options: new Position[](0),
      futures: new Position[](0),
      perps: new Position[](0),
      signers: signers
    });

    assertionContract.setSubAccount(subAccount);

    assertionContract.assertSubAccSignerPermission(testSubAccount, signer, expectedPermission);
  }

  function testAssertFundingIndex() public {
    bytes32 assetID = bytes32("BTC-USD");
    int64 expectedIndex = 1000000;

    assertionContract.setFundingIndex(assetID, expectedIndex);

    assertionContract.assertFundingIndex(assetID, expectedIndex);
  }

  function testAssertMarkPrice() public {
    bytes32 assetID = assetToID(
      Asset({kind: Kind.SPOT, underlying: Currency.BTC, quote: Currency.UNSPECIFIED, expiration: 0, strikePrice: 0})
    );
    uint64 expectedPrice = 50000 * 1e9; // 50,000 USD with 9 decimals
    bool expectedIsSet = true;

    assertionContract.setMarkPrice(assetID, expectedPrice);

    assertionContract.assertMarkPrice(assetID, expectedPrice, expectedIsSet);
  }

  function testAssertSettlementPrice() public {
    bytes32 assetID = bytes32("BTC-USD");
    uint64 expectedValue = 49000 * 1e9; // 49,000 USD with 9 decimals
    bool expectedIsSet = true;

    assertionContract.setSettlementPrice(assetID, expectedValue, expectedIsSet);

    assertionContract.assertSettlementPrice(assetID, expectedValue, expectedIsSet);
  }

  function testAssertInterestRate() public {
    bytes32 assetID = bytes32("BTC-USD");
    int32 expectedRate = 500; // 5% with 2 decimals

    assertionContract.setInterestRate(assetID, expectedRate);

    assertionContract.assertInterestRate(assetID, expectedRate);
  }

  function testAssertSubAccountPosition() public {
    uint64 subAccountID = testSubAccount;
    bytes32 assetID = assetToID(
      Asset({kind: Kind.PERPS, underlying: Currency.BTC, quote: Currency.USDT, expiration: 0, strikePrice: 0})
    );
    bool expectedFound = true;
    int64 expectedBalance = 100 * 1e8; // 100 contracts with 8 decimals
    int64 expectedLastAppliedFundingIndex = 1000000;

    Position[] memory positions = new Position[](1);
    positions[0] = Position({
      id: assetID,
      balance: expectedBalance,
      lastAppliedFundingIndex: expectedLastAppliedFundingIndex
    });

    SubAccountAssertion memory subAccount = SubAccountAssertion({
      id: subAccountID,
      adminCount: 1,
      signerCount: 1,
      accountID: testAccount,
      marginType: MarginType.SIMPLE_CROSS_MARGIN,
      quoteCurrency: Currency.USDC,
      lastAppliedFundingTimestamp: 0,
      spotBalances: new SpotBalanceAssertion[](0),
      options: new Position[](0),
      futures: new Position[](0),
      perps: positions,
      signers: new SignerAssertion[](0)
    });

    assertionContract.setSubAccount(subAccount);

    assertionContract.assertSubAccountPosition(
      subAccountID,
      assetID,
      expectedFound,
      expectedBalance,
      expectedLastAppliedFundingIndex
    );
  }

  function testAssertSubAccountSpotBalance() public {
    Currency currency = Currency.USDT;
    int64 expectedBalance = 2000 * 1e6; // 2,000 USDT with 6 decimals

    SpotBalanceAssertion[] memory spotBalances = new SpotBalanceAssertion[](1);
    spotBalances[0] = SpotBalanceAssertion({currency: currency, balance: expectedBalance});

    bytes32 assetID = assetToID(
      Asset({kind: Kind.SPOT, underlying: Currency.USDT, quote: Currency.UNSPECIFIED, expiration: 0, strikePrice: 0})
    );
    uint64 expectedPrice = 2000000000; // 2 USD/USDT with 9 decimals

    assertionContract.setMarkPrice(assetID, expectedPrice);

    SubAccountAssertion memory subAccount = SubAccountAssertion({
      id: testSubAccount,
      adminCount: 1,
      signerCount: 1,
      accountID: testAccount,
      marginType: MarginType.SIMPLE_CROSS_MARGIN,
      quoteCurrency: Currency.USDT,
      lastAppliedFundingTimestamp: 0,
      spotBalances: spotBalances,
      options: new Position[](0),
      futures: new Position[](0),
      perps: new Position[](0),
      signers: new SignerAssertion[](0)
    });

    assertionContract.setSubAccount(subAccount);

    assertionContract.assertSubAccountSpotBalance(testSubAccount, currency, expectedBalance);

    assertionContract.assertSubAccountValue(testSubAccount, expectedBalance * 2);
  }
}
