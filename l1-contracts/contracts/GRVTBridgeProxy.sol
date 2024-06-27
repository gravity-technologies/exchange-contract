// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interfaces/IBridgeHub.sol";

contract GRVTBridgeProxy is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    event Initialized(
        uint256 chainID,
        address bridgeHub,
        address owner,
        address depositApprover
    );
    event TokenAllowed(address token);
    event TokenDisallowed(address token);

    event BridgeProxyDepositInitiated(
        bytes32 indexed txDataHash,
        bytes32 indexed l2DepositTxHash,
        address indexed from,
        address to,
        address l1Token,
        uint256 amount
    );

    event ClaimedFailedDepositBridgeProxy(
        address indexed to,
        address indexed l1Token,
        uint256 amount,
        bool sharedBridgeClaimSucceeded
    );

    uint256 public chainID;
    IBridgehub public bridgeHub;
    address public depositApprover;

    mapping(address => bool) private allowedTokens;
    mapping(bytes32 => bool) private usedDepositHashes;
    mapping(bytes32 l2DepositTxHash => bytes32 depositDataHash)
        public depositHappened;

    // Functions for initialization and configuration
    // onlyOwner is allowed to call
    function initialize(
        uint256 _chainID,
        address _bridgeHub,
        address _owner,
        address _depositApprover
    ) external initializer {
        chainID = _chainID;
        bridgeHub = IBridgehub(_bridgeHub);
        depositApprover = _depositApprover;

        require(_owner != address(0), "ShB owner 0");
        _transferOwnership(_owner);

        __ReentrancyGuard_init();
        emit Initialized(_chainID, _bridgeHub, _owner, _depositApprover);
    }

    function getDepositApprover() external view returns (address) {
        return depositApprover;
    }

    function addAllowedToken(address _token) external onlyOwner {
        allowedTokens[_token] = true;
        emit TokenAllowed(_token);
    }

    function removeAllowedToken(address _token) external onlyOwner {
        allowedTokens[_token] = false;
        emit TokenDisallowed(_token);
    }

    // Core functions
    function deposit(
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external payable nonReentrant returns (bytes32 txHash) {
        require(
            allowedTokens[_l1Token],
            "GRVTBridgeProxy: L1 token not allowed"
        );

        _verifyDepositApprovalSignature(
            msg.sender,
            _l2Receiver,
            _l1Token,
            _amount,
            _deadline,
            _v,
            _r,
            _s
        );

        address sharedBridge = address(bridgeHub.sharedBridge());

        IERC20(_l1Token).safeTransferFrom(msg.sender, address(this), _amount);
        require(
            IERC20(_l1Token).approve(address(sharedBridge), _amount),
            "GRVTBridgeProxy: approve failed"
        );

        txHash = bridgeHub.requestL2TransactionTwoBridges{value: msg.value}(
            L2TransactionRequestTwoBridgesOuter({
                chainId: chainID,
                mintValue: msg.value,
                l2Value: 0,
                l2GasLimit: 72000000,
                l2GasPerPubdataByteLimit: 800,
                refundRecipient: address(0),
                secondBridgeAddress: sharedBridge,
                secondBridgeValue: 0,
                secondBridgeCalldata: abi.encode(_l1Token, _amount, _l2Receiver)
            })
        );

        // note that the data hash is not the same as what L1SharedBridge saves
        // (first field is the proxy caller)
        // txHash is the canonicalTxHash for L2 transction
        bytes32 txDataHash = keccak256(
            abi.encode(msg.sender, _l1Token, _amount)
        );

        depositHappened[txHash] = txDataHash;

        emit BridgeProxyDepositInitiated(
            txDataHash,
            txHash,
            msg.sender,
            _l2Receiver,
            _l1Token,
            _amount
        );
    }

    function claimFailedDeposit(
        address _depositSender,
        address _l1Token,
        uint256 _amount,
        bytes32 _l2TxHash,
        uint256 _l2BatchNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBatch,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        {
            bool proofValid = bridgeHub.proveL1ToL2TransactionStatus({
                _chainId: chainID,
                _l2TxHash: _l2TxHash,
                _l2BatchNumber: _l2BatchNumber,
                _l2MessageIndex: _l2MessageIndex,
                _l2TxNumberInBatch: _l2TxNumberInBatch,
                _merkleProof: _merkleProof,
                _status: TxStatus.Failure
            });
            require(proofValid, "GRVTBridgeProxy: invalid proof");
        }
        require(_amount > 0, "GRVTBridgeProxy: amount must be larger than 0");

        // no legacy bridge check as that is not applicable for our chain
        bytes32 dataHash = depositHappened[_l2TxHash];
        bytes32 txDataHash = keccak256(
            abi.encode(_depositSender, _l1Token, _amount)
        );

        require(
            dataHash == txDataHash,
            "GRVTBridgeProxy: deposit didn not happen"
        );
        delete depositHappened[_l2TxHash];

        IL1SharedBridge sharedBridge = bridgeHub.sharedBridge();

        bool sharedBridgeClaimSucceeded;
        try
            sharedBridge.claimFailedDeposit(
                chainID,
                address(this),
                _l1Token,
                _amount,
                _l2TxHash,
                _l2BatchNumber,
                _l2MessageIndex,
                _l2TxNumberInBatch,
                _merkleProof
            )
        {
            sharedBridgeClaimSucceeded = true;
        } catch {
            sharedBridgeClaimSucceeded = false;
        }

        // We transfer the amount to the deposit sender no matter
        // whether the claim with the shared bridge succeeded or not
        // as the failed deposit proof is valid and has not been used
        // before.
        // The shared bridge claim can fail if it has already been claimed
        // in which case the amount to refund is already paid to this contract
        IERC20(_l1Token).safeTransfer(_depositSender, _amount);

        emit ClaimedFailedDepositBridgeProxy(
            _depositSender,
            _l1Token,
            _amount,
            sharedBridgeClaimSucceeded
        );
    }

    function isTokenAllowed(address _token) external view returns (bool) {
        return allowedTokens[_token];
    }

    function _verifyDepositApprovalSignature(
        address _l1Sender,
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        require(
            block.timestamp <= _deadline,
            "GRVTBridgeProxy: expired deadline"
        );

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                PREFIXED_DOMAIN_SEPARATOR,
                _getDepositApprovalHash(
                    _l1Sender,
                    _l2Receiver,
                    _l1Token,
                    _amount,
                    _deadline
                )
            )
        );

        // TODO: we can consider using nouce here, this imposes a limit of 1 tx per second, but requires
        // the signer service to read the nonce from the contract
        require(
            !usedDepositHashes[msgHash],
            "GRVTBridgeProxy: deposit approval already used"
        );

        (address addr, ECDSA.RecoverError err) = ECDSA.tryRecover(
            msgHash,
            _v,
            _r,
            _s
        );
        require(
            err == ECDSA.RecoverError.NoError && addr == depositApprover,
            "GRVTBridgeProxy: invalid signature"
        );

        usedDepositHashes[msgHash] = true;
    }

    bytes32 private constant eip712domainTypehash =
        keccak256("EIP712Domain(string name,string version,uint256 chainId)");
    bytes32 private constant DOMAIN_SEPARATOR =
        keccak256(
            abi.encode(
                eip712domainTypehash,
                keccak256(bytes("GRVT Exchange")),
                keccak256(bytes("0")),
                1
            )
        );
    bytes private constant PREFIXED_DOMAIN_SEPARATOR =
        abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR);

    bytes32 private constant DEPOSIT_APPROVAL_TYPEHASH =
        keccak256(
            "DepositApproval(address l1Sender,address l2Receiver,address l1Token,uint256 amount,uint256 deadline)"
        );

    function _getDepositApprovalHash(
        address _l1Sender,
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        uint256 _deadline
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DEPOSIT_APPROVAL_TYPEHASH,
                    _l1Sender,
                    _l2Receiver,
                    _l1Token,
                    _amount,
                    _deadline
                )
            );
    }
}
