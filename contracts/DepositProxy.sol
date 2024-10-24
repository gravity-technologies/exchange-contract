pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract DepositProxy is Initializable {
  using SafeERC20 for IERC20;

  address public exchangeAddress;
  address public accountID;

  modifier onlyExchange() {
    require(msg.sender == exchangeAddress, "caller is not the exchange");
    _;
  }

  constructor() {
    // Disable initialization to prevent Parity hack.
    _disableInitializers();
  }

  function initialize(address _exchangeAddress, address accountID) external initializer {
    exchangeAddress = _exchangeAddress;
    accountID = accountID;
  }

  function fundExchange(address _token, uint256 _amount) external onlyExchange {
    IERC20(_token).safeTransfer(exchangeAddress, _amount);
  }
}
