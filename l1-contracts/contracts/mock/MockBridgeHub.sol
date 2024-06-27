// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IL1SharedBridge} from "../interfaces/IL1SharedBridge.sol";
import {TxStatus} from "../interfaces/IL1SharedBridge.sol";
import {L2TransactionRequestTwoBridgesOuter, L2TransactionRequestTwoBridgesInner} from "../interfaces/IL1SharedBridge.sol";

// Assuming IL1SharedBridge and TxStatus are defined elsewhere
// interface IL1SharedBridge {}
// enum TxStatus { Pending, Completed, Failed }

// Assuming L2TransactionRequestTwoBridgesOuter is defined elsewhere
// struct L2TransactionRequestTwoBridgesOuter {}

contract MockBridgeHub {
    // Mocked return values for sharedBridge function
    IL1SharedBridge private mockSharedBridge;
    bool private proveResult;

    // Constructor to initialize the mockSharedBridge
    constructor(IL1SharedBridge _mockSharedBridge, bool _proveResult) {
        mockSharedBridge = _mockSharedBridge;
        proveResult = _proveResult;
    }

    // Mock implementation of the sharedBridge function
    function sharedBridge() external view returns (IL1SharedBridge) {
        return mockSharedBridge;
    }

    // Mock implementation of the proveL1ToL2TransactionStatus function
    function proveL1ToL2TransactionStatus(
        uint256,
        bytes32,
        uint256,
        uint256,
        uint16,
        bytes32[] calldata,
        TxStatus
    ) external view returns (bool) {
        return proveResult;
    }

    function requestL2TransactionTwoBridges(
        L2TransactionRequestTwoBridgesOuter calldata _request
    ) external payable returns (bytes32 canonicalTxHash) {
        IL1SharedBridge(_request.secondBridgeAddress).bridgehubDeposit{
            value: _request.secondBridgeValue
        }(
            _request.chainId,
            msg.sender,
            _request.l2Value,
            _request.secondBridgeCalldata
        );
        return
            0x0000000000000000000000000000000000000000000000000000000000000001;
    }
}
