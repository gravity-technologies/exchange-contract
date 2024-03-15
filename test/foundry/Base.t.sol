// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../../contracts/exchange/GRVTExchange.sol";
import "../../contracts/exchange/types/DataStructure.sol";
import {Users} from "./types/Types.sol";

contract BaseTest is Test {
  /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
  bytes32 constant DOMAIN_HASH = bytes32(0x3872804bea0616a4202203552aedc3568e0a2ec586cd6ebbef3dec4e3bd471dd);

  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

  Users internal users;
  uint256 currentTimestamp = block.timestamp;
  uint32 txNonce = 1;

  /*//////////////////////////////////////////////////////////////
                             TEST CONTRACTS
    //////////////////////////////////////////////////////////////*/

  GRVTExchange internal grvtExchange;

  /*//////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
  //////////////////////////////////////////////////////////////*/

  /// @dev A setup function invoked before each test case.
  function setUp() public virtual {
    // Create users for testing.
    users = Users({
      gravity: createUser("gravity"),
      gravityPrivateKey: uint256(keccak256(abi.encodePacked("gravity"))),
      walletOne: createUser("walletOne"),
      walletOnePrivateKey: uint256(keccak256(abi.encodePacked("walletOne"))),
      walletTwo: createUser("walletTwo"),
      walletTwoPrivateKey: uint256(keccak256(abi.encodePacked("walletTwo"))),
      walletThree: createUser("walletThree"),
      walletThreePrivateKey: uint256(keccak256(abi.encodePacked("walletThree"))),
      walletFour: createUser("walletFour"),
      walletFourPrivateKey: uint256(keccak256(abi.encodePacked("walletFour"))),
      walletFive: createUser("walletFive"),
      walletFivePrivateKey: uint256(keccak256(abi.encodePacked("walletFive"))),
      walletSix: createUser("walletSix"),
      walletSixPrivateKey: uint256(keccak256(abi.encodePacked("walletSix"))),
      walletSeven: createUser("walletSeven"),
      walletSevenPrivateKey: uint256(keccak256(abi.encodePacked("walletSeven"))),
      walletEight: createUser("walletEight"),
      walletEightPrivateKey: uint256(keccak256(abi.encodePacked("walletEight")))
    });

    // Make the deployer the default caller in all subsequent tests.
    vm.startPrank({msgSender: users.gravity});
    deployGRVTExchange();
  }

  /// @dev Generates a user, labels its address, and funds it with test balance.
  function createUser(string memory name) internal returns (address payable) {
    address payable user = payable(makeAddr(name));
    vm.label(user, name);
    if (keccak256(bytes(name)) == keccak256(bytes("gravity"))) {
      vm.deal(user, 100 ether);
    }
    return user;
  }

  /// @dev Deploys {GRVTExchange} contract
  function deployGRVTExchange() internal {
    grvtExchange = new GRVTExchange();
    // We don't use this way in prod. When we use the openzeppelin plugin - this is called internally
    grvtExchange.initialize();
    vm.label({account: address(grvtExchange), newLabel: "GRVTExchange"});
  }

  /*//////////////////////////////////////////////////////////////
                            HELPERS
  //////////////////////////////////////////////////////////////*/

  // Generates a signature for a given user
  function getUserSig(
    address signer,
    uint256 privateKey,
    bytes32 domainSeperator,
    bytes32 structHash,
    int64 expiry,
    uint32 nonce
  ) public pure returns (Signature memory sig) {
    bytes32 digest = toTypedDataHash(domainSeperator, structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    sig = Signature(signer, r, s, v, expiry, nonce);
    return sig;
  }

  function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) public pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
  }

  // Progresses the current timestamp and transaction nonce
  function progressToNextTxn() public {
    txNonce++;
    currentTimestamp += (3 days);
  }

  // generates pseudo random numbers we can use as payment IDs and for generating private keys
  uint256 counter = 1;

  function random() public returns (uint32) {
    counter++;
    // sha3 and now have been deprecated
    uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, counter)));
    // Truncate the result to uint32
    return uint32(randomNumber);
  }
}
