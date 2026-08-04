// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SubAccountContract} from "../../contracts/exchange/api/SubAccountContract.sol";
import {AssertionContract} from "../../contracts/exchange/api/AssertionContract.sol";
import {
  Signature,
  Account,
  SubAccount,
  PositionMarginConfig,
  Session,
  AccountPermAdmin,
  SubAccountPermAdmin,
  SubAccountPermTrade
} from "../../contracts/exchange/types/DataStructure.sol";
import {SubAccountMode, MarginType, PositionMarginType, CCY_USDT} from "../../contracts/exchange/types/Enum.sol";
import {hashSetSubAccountMode, _SET_SUB_ACCOUNT_MODE_H} from "../../contracts/exchange/api/signature/generated/SubAccountSig.sol";
import {AssertionSubAccountModeMismatch, AssertionSubFundingTimestampMismatch, AssertionPositionMarginMismatch} from "../../contracts/exchange/api/AssertionError.sol";
import {IAssertion} from "../../contracts/exchange/interfaces/IAssertion.sol";

/// @dev Test harness exposing the signed setSubAccountMode tx + the paired assertion, plus
/// minimal state seeding (account, sub account, signer permissions, sequence bootstrap).
contract SetSubAccountModeHarness is SubAccountContract, AssertionContract {
  function init(address admin) external initializer {
    __ReentrancyGuard_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function grantChainSubmitter(address submitter) external {
    _setupRole(CHAIN_SUBMITTER_ROLE, submitter);
  }

  /// @dev Bootstrap the sequence so _setSequence accepts (timestamp, txID). lastTxID must be != 0.
  function seedSequence(int64 timestamp, uint64 lastTxID) external {
    state.timestamp = timestamp;
    state.lastTxID = lastTxID;
  }

  /// @dev Create an account + sub account directly in storage.
  function seedAccountAndSubAccount(address accountID, uint64 subAccID, SubAccountMode mode) external {
    Account storage acc = state.accounts[accountID];
    acc.id = accountID;
    acc.multiSigThreshold = 1;
    acc.adminCount = 1;
    acc.signers[accountID] = AccountPermAdmin;
    acc.subAccounts.push(subAccID);

    SubAccount storage sub = state.subAccounts[subAccID];
    sub.id = subAccID;
    sub.accountID = accountID;
    sub.marginType = MarginType.SIMPLE_CROSS_MARGIN;
    sub.quoteCurrency = CCY_USDT;
    sub.subAccountMode = mode;
  }

  function setSubAccountSignerPerm(uint64 subAccID, address signer, uint64 perm) external {
    state.subAccounts[subAccID].signers[signer] = perm;
  }

  function setAccountSignerPerm(address accountID, address signer, uint64 perm) external {
    state.accounts[accountID].signers[signer] = perm;
  }

  function seedSessionKey(address sessionKey, address mainSigner, int64 expiry) external {
    state.sessions[sessionKey] = Session({subAccountSigner: mainSigner, expiry: expiry});
  }

  function setMode(uint64 subAccID, SubAccountMode mode) external {
    state.subAccounts[subAccID].subAccountMode = mode;
  }

  function modeOf(uint64 subAccID) external view returns (SubAccountMode) {
    return state.subAccounts[subAccID].subAccountMode;
  }

  function seedPositionMarginConfig(uint64 subAccID, bytes32 assetID, PositionMarginType t, int32 lev) external {
    PositionMarginConfig storage cfg = state.subAccounts[subAccID].positionMarginConfigs[assetID];
    cfg.marginType = t;
    cfg.leverage = lev;
  }

  function marginConfigOf(uint64 subAccID, bytes32 assetID) external view returns (PositionMarginType, int32) {
    PositionMarginConfig storage cfg = state.subAccounts[subAccID].positionMarginConfigs[assetID];
    return (cfg.marginType, cfg.leverage);
  }
}

contract SetSubAccountModeTest is Test {
  SetSubAccountModeHarness internal exchange;

  address internal constant ADMIN = address(0xA11CE);
  address internal constant SUBMITTER = address(0x50B);
  address internal constant ACCOUNT_ID = address(0xACC0);
  uint64 internal constant SUB_ID = 777;

  // Trade-permitted signer
  uint256 internal constant TRADE_PK = 0xA11;
  address internal tradeSigner;

  // No-permission signer (used for negative permission test, and re-permissioned where noted)
  uint256 internal constant NO_PERM_PK = 0xB22;
  address internal noPermSigner;

  // Sub-admin-only signer
  uint256 internal constant SUB_ADMIN_PK = 0xC33;

  function setUp() public {
    exchange = new SetSubAccountModeHarness();
    exchange.init(ADMIN);
    exchange.grantChainSubmitter(SUBMITTER);

    tradeSigner = vm.addr(TRADE_PK);
    noPermSigner = vm.addr(NO_PERM_PK);

    // Seed sequence: timestamp 1000, lastTxID 1 -> next tx must be txID 2.
    exchange.seedSequence(1000, 1);

    // Account + sub account starting in SINGLE_ASSET_MODE.
    exchange.seedAccountAndSubAccount(ACCOUNT_ID, SUB_ID, SubAccountMode.SINGLE_ASSET_MODE);

    // tradeSigner has sub-account TRADE permission.
    exchange.setSubAccountSignerPerm(SUB_ID, tradeSigner, SubAccountPermTrade);
  }

  // ---------- assertion helper ----------

  function _noAssets() internal pure returns (bytes32[] memory a) {}

  function _noConfigs() internal pure returns (IAssertion.PositionMarginConfigAssertion[] memory c) {}

  /// @dev Post-state assertion for a position-less sub in this harness: funding settle
  /// sets lastAppliedFundingTimestamp to state.prices.fundingTime (0 here); no positions
  /// or wallet balances to compare.
  function _subAssertion(uint64 subID) internal pure returns (IAssertion.SubAccountAssertionV2 memory a) {
    a.subAccountID = subID;
  }

  // ---------- signing helper ----------

  function _domainSeparator() internal view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          keccak256("EIP712Domain(string name,string version,uint256 chainId)"),
          keccak256(bytes("GRVT Exchange")),
          keccak256(bytes("0")),
          block.chainid
        )
      );
  }

  function _sign(
    uint256 pk,
    address signer,
    uint64 subAccID,
    SubAccountMode mode,
    uint32 nonce,
    int64 expiration
  ) internal view returns (Signature memory sig) {
    bytes32 structHash = hashSetSubAccountMode(subAccID, mode, nonce, expiration);
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    sig = Signature({signer: signer, r: r, s: s, v: v, expiration: expiration, nonce: nonce, chainId: block.chainid});
  }

  // ---------- happy paths ----------

  function testSamToMamByTradeSigner() public {
    int64 exp = 1000; // == state.timestamp, within 30-day window
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, exp);

    vm.prank(SUBMITTER, SUBMITTER); // sets msg.sender AND tx.origin to SUBMITTER
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    assertEq(uint8(exchange.modeOf(SUB_ID)), uint8(SubAccountMode.MULTI_ASSET_MODE));
    // assertion matches
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.MULTI_ASSET_MODE, _noConfigs());
  }

  function testMamToSamByTradeSigner() public {
    // Start in MAM, switch to SAM.
    exchange.setMode(SUB_ID, SubAccountMode.MULTI_ASSET_MODE);

    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.SINGLE_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.SINGLE_ASSET_MODE, _noAssets(), sig);

    assertEq(uint8(exchange.modeOf(SUB_ID)), uint8(SubAccountMode.SINGLE_ASSET_MODE));
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.SINGLE_ASSET_MODE, _noConfigs());
  }

  function testAccountAdminMayAlsoSwitch() public {
    // Account admin (no explicit sub trade perm) is allowed: hasSubAccountPermission returns true for account admin.
    address acctAdmin = vm.addr(NO_PERM_PK);
    exchange.setAccountSignerPerm(ACCOUNT_ID, acctAdmin, AccountPermAdmin);
    Signature memory sig = _sign(NO_PERM_PK, acctAdmin, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    assertEq(uint8(exchange.modeOf(SUB_ID)), uint8(SubAccountMode.MULTI_ASSET_MODE));
  }

  // ---------- reverts ----------

  function testUnifiedReverts() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.UNIFIED_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("unsupported target mode"));
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.UNIFIED_MODE, _noAssets(), sig);
  }

  function testUnspecifiedReverts() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.UNSPECIFIED, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("unsupported target mode"));
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.UNSPECIFIED, _noAssets(), sig);
  }

  function testNonTradeSignerReverts() public {
    // Signer with NO permission at all on the sub account.
    Signature memory sig = _sign(NO_PERM_PK, noPermSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("no permission"));
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
  }

  function testSignerWithOnlySubAdminButNotTradeStillAllowed() public {
    // SubAccountPermAdmin alone passes hasSubAccountPermission (admin bit). This documents that a
    // sub-admin can switch; the required-perm gate is TRADE but admin short-circuits, matching
    // setDeriskToMaintenanceMarginRatio semantics.
    address subAdmin = vm.addr(SUB_ADMIN_PK);
    exchange.setSubAccountSignerPerm(SUB_ID, subAdmin, SubAccountPermAdmin);
    Signature memory sig = _sign(SUB_ADMIN_PK, subAdmin, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
    assertEq(uint8(exchange.modeOf(SUB_ID)), uint8(SubAccountMode.MULTI_ASSET_MODE));
  }

  function testReplayReverts() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    // Replay the exact same signed payload (advance txID so _setSequence isn't the blocker).
    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("replayed payload"));
    exchange.setSubAccountMode(1000, 3, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
  }

  function testNonSubmitterTxOriginReverts() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    // tx.origin is some random address without CHAIN_SUBMITTER_ROLE.
    vm.prank(address(0xBAD), address(0xBAD));
    vm.expectRevert();
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
  }

  function testWrongSignerInSigReverts() public {
    // Sign with tradePk but claim a different signer address -> ECDSA recover mismatch.
    bytes32 structHash = hashSetSubAccountMode(SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(TRADE_PK, digest);
    // Claim noPermSigner as signer; but give them trade perm so we isolate
    // the signature-mismatch revert rather than a permission revert.
    exchange.setSubAccountSignerPerm(SUB_ID, noPermSigner, SubAccountPermTrade);
    Signature memory sig = Signature({
      signer: noPermSigner,
      r: r,
      s: s,
      v: v,
      expiration: 1000,
      nonce: 1,
      chainId: block.chainid
    });

    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("invalid signature"));
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
  }

  function testAssertionMismatchReverts() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    // Now mode is MULTI; asserting SINGLE must revert.
    vm.expectRevert(AssertionSubAccountModeMismatch.selector);
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.SINGLE_ASSET_MODE, _noConfigs());
  }

  function testAssertionChecksSubAccountState() public {
    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    // The assertion covers the funded sub-account post-state, not just the mode:
    // a wrong funding timestamp must revert.
    IAssertion.SubAccountAssertionV2 memory bad = _subAssertion(SUB_ID);
    bad.fundingTimestamp = 123;
    vm.expectRevert(AssertionSubFundingTimestampMismatch.selector);
    exchange.assertSetSubAccountMode(bad, SubAccountMode.MULTI_ASSET_MODE, _noConfigs());
  }

  // ---------- isolated-assets context (sequencer-stamped conversion) ----------

  function testContextConvertsListedIsolatedConfigsToCross() public {
    bytes32 assetA = bytes32(uint256(0xA1));
    bytes32 assetB = bytes32(uint256(0xB2));
    exchange.seedPositionMarginConfig(SUB_ID, assetA, PositionMarginType.ISOLATED, 15_000_000);
    exchange.seedPositionMarginConfig(SUB_ID, assetB, PositionMarginType.ISOLATED, 7_000_000);

    bytes32[] memory ctx = new bytes32[](1);
    ctx[0] = assetA; // only A is stamped; B stays untouched

    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, ctx, sig);

    (PositionMarginType tA, int32 levA) = exchange.marginConfigOf(SUB_ID, assetA);
    (PositionMarginType tB, int32 levB) = exchange.marginConfigOf(SUB_ID, assetB);
    assertEq(uint8(tA), uint8(PositionMarginType.CROSS), "listed asset converted");
    assertEq(levA, 15_000_000, "leverage preserved");
    assertEq(uint8(tB), uint8(PositionMarginType.ISOLATED), "unlisted asset untouched");
    assertEq(levB, 7_000_000);
  }

  /// @dev The context is trusted (Risk derives it from the same state it stamps from), so the
  /// sweep writes unconditionally: a cross entry is an idempotent write (leverage untouched).
  function testContextWriteIsIdempotentForCrossEntries() public {
    bytes32 assetA = bytes32(uint256(0xA1));
    exchange.seedPositionMarginConfig(SUB_ID, assetA, PositionMarginType.CROSS, 5_000_000);

    bytes32[] memory ctx = new bytes32[](1);
    ctx[0] = assetA;

    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, ctx, sig);

    (PositionMarginType tA, int32 levA) = exchange.marginConfigOf(SUB_ID, assetA);
    assertEq(uint8(tA), uint8(PositionMarginType.CROSS));
    assertEq(levA, 5_000_000);
  }

  // ---------- session key signing (platform allows it; mirrors requireSignerOrSessionKeySubAccountPerm) ----------

  function testSessionKeyOfTradeSignerMaySwitch() public {
    // Session key registered for tradeSigner; the session key signs, permission resolves
    // to the main signer's TRADE permission.
    uint256 sessionPk = 0xD44;
    address sessionKey = vm.addr(sessionPk);
    exchange.seedSessionKey(sessionKey, tradeSigner, 2000); // expiry 2000 > timestamp 1000

    Signature memory sig = _sign(sessionPk, sessionKey, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);

    assertEq(uint8(exchange.modeOf(SUB_ID)), uint8(SubAccountMode.MULTI_ASSET_MODE));
  }

  function testExpiredSessionKeyReverts() public {
    uint256 sessionPk = 0xD44;
    address sessionKey = vm.addr(sessionPk);
    exchange.seedSessionKey(sessionKey, tradeSigner, 999); // expired (< timestamp 1000)

    Signature memory sig = _sign(sessionPk, sessionKey, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);

    vm.prank(SUBMITTER, SUBMITTER);
    vm.expectRevert(bytes("no permission"));
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, _noAssets(), sig);
  }

  // ---------- converted margin configs are asserted ----------

  function testAssertionChecksConvertedMarginConfigs() public {
    bytes32 assetA = bytes32(uint256(0xA1));
    exchange.seedPositionMarginConfig(SUB_ID, assetA, PositionMarginType.ISOLATED, 15_000_000);

    bytes32[] memory ctx = new bytes32[](1);
    ctx[0] = assetA;

    Signature memory sig = _sign(TRADE_PK, tradeSigner, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, 1, 1000);
    vm.prank(SUBMITTER, SUBMITTER);
    exchange.setSubAccountMode(1000, 2, SUB_ID, SubAccountMode.MULTI_ASSET_MODE, ctx, sig);

    // Matching post-state passes: converted to CROSS, leverage preserved.
    IAssertion.PositionMarginConfigAssertion[] memory cfgs = new IAssertion.PositionMarginConfigAssertion[](1);
    cfgs[0] = IAssertion.PositionMarginConfigAssertion({
      assetID: assetA,
      marginType: PositionMarginType.CROSS,
      leverage: 15_000_000
    });
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.MULTI_ASSET_MODE, cfgs);

    // Wrong margin type must revert.
    cfgs[0].marginType = PositionMarginType.ISOLATED;
    vm.expectRevert(AssertionPositionMarginMismatch.selector);
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.MULTI_ASSET_MODE, cfgs);

    // Wrong leverage must revert.
    cfgs[0].marginType = PositionMarginType.CROSS;
    cfgs[0].leverage = 1;
    vm.expectRevert(AssertionPositionMarginMismatch.selector);
    exchange.assertSetSubAccountMode(_subAssertion(SUB_ID), SubAccountMode.MULTI_ASSET_MODE, cfgs);
  }

  function testTypeHashByteExact() public {
    // Guards the EIP-712 type string against drift; must be byte-identical to the platform's.
    assertEq(
      _SET_SUB_ACCOUNT_MODE_H,
      keccak256("SetSubAccountMode(uint64 subAccountID,uint8 subAccountMode,uint32 nonce,int64 expiration)")
    );
  }
}
