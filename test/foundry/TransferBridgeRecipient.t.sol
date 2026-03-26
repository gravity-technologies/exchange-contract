// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransferContract} from "../../contracts/exchange/api/TransferContract.sol";
import {ConfigID, ConfigValue} from "../../contracts/exchange/types/DataStructure.sol";
import {Currency} from "../../contracts/exchange/types/Enum.sol";

contract TransferContractHarness is TransferContract {
    function setBridgeRecipients(address l1DefiVault, address nativeVaultGateway) external {
        state.l1DefiVaultAddress = l1DefiVault;
        state.nativeVaultGatewayAddress = nativeVaultGateway;
    }

    function setCurrencyERC20Address(Currency currency, address token) external {
        state.config2DValues[ConfigID.ERC20_ADDRESSES][_currencyToConfig(currency)] = ConfigValue({
            val: _addressToConfig(token),
            isSet: true
        });
    }

    function setDefaultCurrencyERC20Address(address token) external {
        state.config2DValues[ConfigID.ERC20_ADDRESSES][bytes32(uint256(0))] = ConfigValue({
            val: _addressToConfig(token),
            isSet: true
        });
    }

    function getL1BridgeRecipient(address l2Token) external view returns (address) {
        return _getL1BridgeRecipient(l2Token);
    }
}

contract TransferBridgeRecipientTest is Test {
    TransferContractHarness internal transferContract;

    address internal constant L1_DEFI_VAULT = address(0xA11CE);
    address internal constant NATIVE_VAULT_GATEWAY = address(0xB0B);
    address internal constant USDT_L2 = address(0x1001);
    address internal constant ETH_L2 = address(0x1002);

    function setUp() public {
        transferContract = new TransferContractHarness();
        transferContract.setBridgeRecipients(L1_DEFI_VAULT, NATIVE_VAULT_GATEWAY);
    }

    function testGetL1BridgeRecipientFallsBackToL1VaultWhenEthConfigMissing() public {
        assertEq(transferContract.getL1BridgeRecipient(USDT_L2), L1_DEFI_VAULT);
    }

    function testGetL1BridgeRecipientUsesNativeGatewayForConfiguredEthToken() public {
        transferContract.setCurrencyERC20Address(Currency.ETH, ETH_L2);

        assertEq(transferContract.getL1BridgeRecipient(ETH_L2), NATIVE_VAULT_GATEWAY);
    }

    function testGetL1BridgeRecipientKeepsNonEthTokensOnL1VaultWhenEthConfigExists() public {
        transferContract.setCurrencyERC20Address(Currency.ETH, ETH_L2);

        assertEq(transferContract.getL1BridgeRecipient(USDT_L2), L1_DEFI_VAULT);
    }

    function testGetL1BridgeRecipientIgnoresDefaultEntryWhenEthConfigMissing() public {
        transferContract.setDefaultCurrencyERC20Address(USDT_L2);

        assertEq(transferContract.getL1BridgeRecipient(USDT_L2), L1_DEFI_VAULT);
    }
}
