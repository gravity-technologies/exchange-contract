// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ITransactionFilterer} from "./interfaces/ITransactionFilterer.sol";
import {IL2Bridge} from "./interfaces/IL2Bridge.sol";

contract GRVTTransactionFilterer is OwnableUpgradeable, ITransactionFilterer {
    event Initialized(
        address l1SharedBridge,
        address l2Bridge,
        address grvtBridgeProxy,
        address owner
    );

    address public l1SharedBridge;
    address public l2Bridge;
    address public grvtBridgeProxy;

    function initialize(
        address _l1SharedBridge,
        address _l2Bridge,
        address _grvtBridgeProxy,
        address _owner
    ) external initializer {
        l1SharedBridge = _l1SharedBridge;
        l2Bridge = _l2Bridge;
        grvtBridgeProxy = _grvtBridgeProxy;

        require(_owner != address(0), "ShB owner 0");
        _transferOwnership(_owner);

        emit Initialized(_l1SharedBridge, _l2Bridge, _grvtBridgeProxy, _owner);
    }

    function setL1SharedBridge(address _l1SharedBridge) external onlyOwner {
        l1SharedBridge = _l1SharedBridge;
    }

    function setL2Bridge(address _l2Bridge) external onlyOwner {
        l2Bridge = _l2Bridge;
    }

    function setGrvtBridgeProxy(address _grvtBridgeProxy) external onlyOwner {
        grvtBridgeProxy = _grvtBridgeProxy;
    }

    function isTransactionAllowed(
        address sender,
        address contractL2,
        uint256,
        uint256,
        bytes memory l2Calldata,
        address
    ) external view override returns (bool) {
        bytes memory paramsData = new bytes(l2Calldata.length - 4);

        if (l2Calldata.length < 4) {
            return false;
        }

        bytes4 selector;
        assembly {
            selector := mload(add(l2Calldata, 32))
        }

        if (selector != IL2Bridge.finalizeDeposit.selector) {
            return false;
        }

        for (uint256 i = 4; i < l2Calldata.length; i++) {
            paramsData[i - 4] = l2Calldata[i];
        }

        (address l1Sender, , , , ) = abi.decode(
            paramsData,
            (address, address, address, uint256, bytes)
        );

        return
            sender == l1SharedBridge &&
            contractL2 == l2Bridge &&
            l1Sender == grvtBridgeProxy;
    }
}
