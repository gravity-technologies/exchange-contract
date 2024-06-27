// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {L2TransactionRequestTwoBridgesInner} from "../interfaces/IL1SharedBridge.sol";

contract MockL1SharedBridge {
    using SafeERC20 for IERC20;

    bool claimSuccess;

    constructor(bool _claimSuccess) {
        claimSuccess = _claimSuccess;
    }

    function setClaimSuccess(bool _claimSuccess) external {
        claimSuccess = _claimSuccess;
    }

    function bridgehubDeposit(
        uint256,
        address _prevMsgSender,
        uint256,
        bytes calldata _data
    )
        external
        payable
        returns (L2TransactionRequestTwoBridgesInner memory request)
    {
        (address _l1Token, uint256 _depositAmount, ) = abi.decode(
            _data,
            (address, uint256, address)
        );
        IERC20(_l1Token).safeTransferFrom(
            _prevMsgSender,
            address(this),
            _depositAmount
        );

        request = L2TransactionRequestTwoBridgesInner({
            magicValue: "",
            l2Contract: address(0),
            l2Calldata: new bytes(0),
            factoryDeps: new bytes[](0),
            txDataHash: bytes32(0)
        });
    }

    function claimFailedDeposit(
        uint256,
        address _depositSender,
        address _l1Token,
        uint256 _amount,
        bytes32,
        uint256,
        uint256,
        uint16,
        bytes32[] calldata
    ) external {
        require(claimSuccess, "claim failed");
        IERC20(_l1Token).safeTransfer(_depositSender, _amount);
    }
}
