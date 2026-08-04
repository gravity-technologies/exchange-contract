// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AccountContract} from "../../contracts/exchange/api/AccountContract.sol";

// Expose internal function for testing
contract AccountContractHarness is AccountContract {
    function getAccountPermissionsString(uint64 permissions) public pure returns (string memory) {
        return _getAccountPermissionsString(permissions);
    }
}

contract AccountPermissionsStringTest is Test {
    AccountContractHarness public accountContract;

    uint64 constant AccountPermAdmin = 1 << 1;
    uint64 constant AccountPermInternalTransfer = 1 << 2;
    uint64 constant AccountPermExternalTransfer = 1 << 3;
    uint64 constant AccountPermWithdraw = 1 << 4;
    uint64 constant AccountPermVaultInvestor = 1 << 5;
    uint64 constant AccountPermTrade = 1 << 6;

    function setUp() public {
        accountContract = new AccountContractHarness();
    }

    function testGetAccountPermissionsString() public {
        // Single permissions
        assertEq(accountContract.getAccountPermissionsString(AccountPermAdmin), "Admin");
        assertEq(accountContract.getAccountPermissionsString(AccountPermInternalTransfer), "InternalTransfer");
        assertEq(accountContract.getAccountPermissionsString(AccountPermExternalTransfer), "ExternalTransfer");
        assertEq(accountContract.getAccountPermissionsString(AccountPermWithdraw), "Withdraw");
        assertEq(accountContract.getAccountPermissionsString(AccountPermVaultInvestor), "VaultInvestor");
        assertEq(accountContract.getAccountPermissionsString(AccountPermTrade), "Trade");

        // Combinations
        assertEq(accountContract.getAccountPermissionsString(AccountPermAdmin | AccountPermInternalTransfer), "Admin&InternalTransfer");
        assertEq(accountContract.getAccountPermissionsString(AccountPermAdmin | AccountPermTrade), "Admin&Trade");
        assertEq(accountContract.getAccountPermissionsString(AccountPermWithdraw | AccountPermTrade), "Withdraw&Trade");
        
        // Triple combination
        assertEq(
            accountContract.getAccountPermissionsString(AccountPermAdmin | AccountPermWithdraw | AccountPermTrade),
             "Admin&Withdraw&Trade"
        );

        // All permissions
        uint64 allPerms = AccountPermAdmin | AccountPermInternalTransfer | AccountPermExternalTransfer | AccountPermWithdraw | AccountPermVaultInvestor | AccountPermTrade;
        assertEq(
            accountContract.getAccountPermissionsString(allPerms),
            "Admin&InternalTransfer&ExternalTransfer&Withdraw&VaultInvestor&Trade"
        );
    }
}
