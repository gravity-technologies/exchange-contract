// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

struct Users {
  address payable gravity;
  address payable walletOne;
  address payable walletTwo;
  address payable walletThree;
  address payable walletFour;
  address payable walletFive;
  address payable walletSix;
  address payable walletSeven;
  address payable walletEight;
  uint256 gravityPrivateKey;
  uint256 walletOnePrivateKey;
  uint256 walletTwoPrivateKey;
  uint256 walletThreePrivateKey;
  uint256 walletFourPrivateKey;
  uint256 walletFivePrivateKey;
  uint256 walletSixPrivateKey;
  uint256 walletSevenPrivateKey;
  uint256 walletEightPrivateKey;
}

struct Traders {
  Trader traderOne;
  Trader traderTwo;
  Trader traderThree;
  Trader traderFour;
  Trader traderFive;
  Trader traderSix;
  Trader traderSeven;
}

struct Trader {
  address payable signer;
  uint256 privateKey;
  address accID;
  uint64 subAccID;
}
