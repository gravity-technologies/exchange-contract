// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../../contracts/exchange/GRVTExchange.sol";
import {Users} from "./types/Types.sol";

contract Base_Test is Test {
  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

  Users internal users;

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
      walletOne: createUser("walletOne"),
      walletTwo: createUser("walletTwo"),
      walletThree: createUser("walletThree"),
      walletFour: createUser("walletFour"),
      walletFive: createUser("walletFive"),
      walletSix: createUser("walletSix"),
      walletSeven: createUser("walletSeven")
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
    bytes32[] memory _initialConfig = new bytes32[](0);
    grvtExchange.initialize(_initialConfig);
    vm.label({account: address(grvtExchange), newLabel: "GRVTExchange"});
  }
}
