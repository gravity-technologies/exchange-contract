import { Contract, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import {
  genAddAccountAdminSig,
  genCreateSubAccountSig,
  genSetAccountMultiSigThresholdSig,
  genRemoveAccountAdminSig,
  genAddWithdrawalAddressSig,
  genRemoveWithdrawalAddressSig,
  genAddTransferSubAccountPayloadSig,
  genRemoveTransferSubAccountPayloadSig,
} from './signature'
import { expectNotToThrowAsync, expectToThrowAsync } from './util'
import { randomInt } from 'crypto'

function wallet(): Wallet {
  return ethers.Wallet.createRandom()
}

function nonce() {
  return randomInt(22021991)
}

describe('API - Account', function () {
  let contract: Contract

  beforeEach(async () => {
    contract = await ethers.deployContract('GRVTExchange')
  })

  // TODO: fix this test
  describe('createSubAccount', function () {
    it('Should create sub account successfully', async function () {
      const w = wallet()
      // console.log('📮 SignerAddress    = ', w.address.toLocaleLowerCase())
      const salt = nonce()
      const sig = genCreateSubAccountSig(w, 1, w.address, 2, 3, salt)
      const accID = 1

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [sig]
      )
    })

    it('Error if account already exists', async function () {
      const w = wallet()
      const accID = 1

      const salt = nonce()
      const sig = genCreateSubAccountSig(w, 1, w.address, 2, 3, salt)
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [sig] // signature
      )
      expectToThrowAsync(
        contract.createSubAccount(
          2, // timestamp
          2, // txID
          accID, // accountID
          w.address, // subAccountID
          2, // quoteCurrency: USDC
          3, // marginType: PORTFOLIO_CROSS_MARGIN
          salt,
          [sig] // signature
        )
      )
    })
  })

  describe('addAccountAdmin', function () {
    it('Should add admin successfully', async function () {
      const w1 = wallet()
      const w2 = wallet()

      const salt = nonce()
      const accID = 1
      // 1. Create sub account
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )
      await contract.addAccountAdmin(
        2, // timestamp
        2, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genAddAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )
    })

    it('Reject if account does not exist', async function () {
      const w = wallet()
      const salt = nonce()
      const accID = 1
      expectToThrowAsync(
        contract.addAccountAdmin(
          2, // timestamp
          2, // txID
          accID, // accountID
          w.address, // signer
          salt,
          [genAddAccountAdminSig(w, 1, wallet().address, salt)] // signature
        )
      )
    })

    it('No-op if admin address already exists', async function () {
      const w = wallet()
      const salt = nonce()
      const accID = 1
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )
      expectNotToThrowAsync(
        contract.addAccountAdmin(
          2, // timestamp
          2, // txID
          accID, // accountID
          w.address, // signer
          salt,
          [genAddAccountAdminSig(w, accID, w.address, salt)] // signature
        )
      )
    })
  })

  describe('removeAccountAdmin', function () {
    it('Should remove successfully', async function () {
      const w1 = wallet()
      const w2 = wallet()
      const salt = nonce()
      const accID = 1

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      await contract.addAccountAdmin(
        2, // timestamp
        2, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genAddAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )

      await contract.removeAccountAdmin(
        3, // timestamp
        3, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genRemoveAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )
    })

    it('Error when removing the last admin', async function () {
      const w1 = wallet()
      const w2 = wallet()
      const salt = nonce()
      const accID = 1

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      expectToThrowAsync(
        contract.removeAccountAdmin(
          3, // timestamp
          3, // txID
          accID, // accountID
          w1.address, // signer
          salt,
          [genRemoveAccountAdminSig(w1, accID, w1.address, salt)] // signature
        )
      )
    })

    it('Error if account does not exist', async function () {
      const w1 = wallet()
      const accID = 1
      const salt = nonce()

      expectToThrowAsync(
        contract.removeAccountAdmin(
          2, // timestamp
          2, // txID
          accID, // accountID
          w1.address, // signer
          salt,
          [genRemoveAccountAdminSig(w1, accID, w1.address, salt)] // signature
        )
      )
    })

    it('Error if admin address does not exist', async function () {
      const w1 = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      expectToThrowAsync(
        contract.removeAccountAdmin(
          2, // timestamp
          2, // txID
          accID, // accountID
          w1.address, // signer
          salt,
          [genRemoveAccountAdminSig(w1, accID, w1.address, salt)] // signature
        )
      )
    })
  })

  describe('addWithdrawalAddress', function () {
    it('should add withdrawal address successfully', async function () {
      const w = wallet()
      const withdrawalAddress = wallet().address
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )
      await contract.addWithdrawalAddress(
        2, // timestamp
        2, // txID
        accID, // accountID
        withdrawalAddress,
        salt,
        [genAddWithdrawalAddressSig(w, accID, withdrawalAddress, salt)] // signature
      )
    })

    it('Reject if account does not exist', async function () {
      const withdrawalAddress = wallet().address
      const accID = 1
      const salt = nonce()

      expectToThrowAsync(
        contract.addWithdrawalAddress(
          1, // timestamp
          1, // txID
          accID, // accountID
          withdrawalAddress,
          salt,
          [genAddWithdrawalAddressSig(wallet(), accID, withdrawalAddress, salt)] // signature
        )
      )
    })

    it('Reject if withdrawal address already exists', async function () {
      const w = wallet()
      const withdrawalAddress = wallet().address
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      await contract.addWithdrawalAddress(
        2, // timestamp
        2, // txID
        accID, // accountID
        withdrawalAddress,
        salt,
        [genAddWithdrawalAddressSig(w, accID, withdrawalAddress, salt)] // signature
      )

      expectToThrowAsync(
        contract.addWithdrawalAddress(
          3, // timestamp
          3, // txID
          accID, // accountID
          withdrawalAddress,
          salt,
          [genAddWithdrawalAddressSig(w, accID, withdrawalAddress, salt)] // signature
        )
      )
    })
  })

  describe('removeWithdrawalAddress', function () {
    it('Should remove withdrawal address successfully', async function () {
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const withdrawalAddress = wallet().address
      await contract.addWithdrawalAddress(
        2, // timestamp
        2, // txID
        accID, // accountID
        withdrawalAddress, // withdrawalAddress
        salt,
        [genAddWithdrawalAddressSig(w, accID, withdrawalAddress, salt)] // signature
      )

      await contract.removeWithdrawalAddress(
        3, // timestamp
        3, // txID
        accID, // accountID
        withdrawalAddress, // withdrawalAddress
        salt,
        [genRemoveWithdrawalAddressSig(w, accID, withdrawalAddress, salt)] // signature
      )
    })

    it('Error if account does not exist', async function () {
      const withdrawalAddress = wallet().address
      const accID = 1
      const salt = nonce()

      expectToThrowAsync(
        contract.removeWithdrawalAddress(
          2, // timestamp
          2, // txID
          accID, // accountID
          withdrawalAddress, // withdrawalAddress
          salt,
          [genRemoveWithdrawalAddressSig(wallet(), accID, withdrawalAddress, salt)]
        )
      )
    })

    it('Error if withdrawal address does not exist', async function () {
      // Create an account explicitly for this test
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const withdrawalAddress1 = wallet().address
      const withdrawalAddress2 = wallet().address

      // Add withdrawal address explicitly for this test
      await contract.addWithdrawalAddress(
        2, // timestamp
        2, // txID
        accID, // accountID
        withdrawalAddress1, // withdrawalAddress
        salt,
        [genAddWithdrawalAddressSig(w, accID, withdrawalAddress1, salt)] // signature
      )

      expectToThrowAsync(
        contract.removeWithdrawalAddress(
          3, // timestamp
          3, // txID
          accID, // accountID
          withdrawalAddress2, // withdrawalAddress
          salt,
          [genRemoveWithdrawalAddressSig(w, accID, withdrawalAddress2, salt)] // signature
        )
      )
    })
  })

  describe('addTransferSubAccount', function () {
    it('Success', async function () {
      // Create an account explicitly for this test
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const transferSubAccount = wallet().address
      await contract.addTransferSubAccount(
        2, // timestamp
        2, // txID
        accID, // accountID
        transferSubAccount, // transferSubAccount
        salt,
        [genAddTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)] // signature
      )
    })

    it('Reject if account does not exist', async function () {
      const transferSubAccount = wallet().address
      const accID = 1
      const salt = nonce()
      const w = wallet()

      expectToThrowAsync(
        contract.addTransferSubAccount(
          2, // timestamp
          2, // txID
          accID, // accountID
          transferSubAccount, // transferSubAccount
          salt,
          [genAddTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
        )
      )
    })

    it('No-op if transfer subaccount already exists', async function () {
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const transferSubAccount = wallet().address

      // Add transfer subaccount explicitly for this test
      await contract.addTransferSubAccount(
        2, // timestamp
        2, // txID
        accID, // accountID
        transferSubAccount, // transferSubAccount
        salt,
        [genAddTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
      )

      expectNotToThrowAsync(
        contract.addTransferSubAccount(
          3, // timestamp
          3, // txID
          accID, // accountID
          transferSubAccount, // transferSubAccount
          salt,
          [genAddTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
        )
      )
    })
  })

  describe('setAccountMultiSigThreshold', function () {
    it('Should update multisig threshold successfully', async function () {
      const w1 = wallet()
      const w2 = wallet()

      const accID = 1
      const salt = nonce()
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      await contract.addAccountAdmin(
        2, // timestamp
        2, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genAddAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )

      await contract.setAccountMultiSigThreshold(
        3, // timestamp
        3, // txID
        accID, // accountID
        2, // multiSigThreshold
        salt,
        [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
      )
    })

    it('Reject if threshold = 0', async function () {
      // TODO: add 1 admin here
      const accID = 1
      const salt = nonce()
      expectToThrowAsync(
        contract.setAccountMultiSigThreshold(
          2, // timestamp
          2, // txID
          accID, // accountID
          0, // multiSigThreshold
          salt,
          [genSetAccountMultiSigThresholdSig(wallet(), accID, 0, salt)] // signature
        )
      )
    })

    it('Reject if threshold > number of admins', async function () {
      const accID = 1
      const salt = nonce()
      expectToThrowAsync(
        contract.setAccountMultiSigThreshold(
          2, // timestamp
          2, // txID
          accID, // accountID
          3, // multiSigThreshold
          [genSetAccountMultiSigThresholdSig(wallet(), accID, 3, salt)] // signature
        )
      )
    })
  })

  describe('removeTransferSubAccount', function () {
    it('Should remove transfer subaccount successfully', async function () {
      // Create an account explicitly for this test
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const transferSubAccount = wallet().address
      await contract.addTransferSubAccount(
        2, // timestamp
        2, // txID
        accID, // accountID
        transferSubAccount, // transferSubAccount
        salt,
        [genAddTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)] // signature
      )

      expectNotToThrowAsync(
        contract.removeTransferSubAccount(
          2, // timestamp
          2, // txID
          accID, // accountID
          transferSubAccount, // transferSubAccount
          salt,
          [genRemoveTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
        )
      )
    })

    it('Reject if account does not exist', async function () {
      const transferSubAccount = wallet().address
      const accID = 1
      const salt = nonce()
      const w = wallet()

      expectToThrowAsync(
        contract.removeTransferSubAccount(
          2, // timestamp
          2, // txID
          accID, // accountID
          transferSubAccount, // transferSubAccount
          salt,
          [genRemoveTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
        )
      )
    })

    it('Reject if transfer subaccount doesn not exist', async function () {
      const w = wallet()
      const accID = 1
      const salt = nonce()

      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w, accID, w.address, 2, 3, salt)] // signature
      )

      const transferSubAccount = wallet().address
      expectToThrowAsync(
        contract.removeTransferSubAccount(
          3, // timestamp
          3, // txID
          accID, // accountID
          transferSubAccount, // transferSubAccount
          salt,
          [genRemoveTransferSubAccountPayloadSig(w, accID, transferSubAccount, salt)]
        )
      )
    })
  })

  describe('Security - Prevent Replay Attack', function () {
    it('Should not allow updating replaying update multisig threshold', async function () {
      const w1 = wallet()
      const w2 = wallet()

      const accID = 1
      const salt = nonce()
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      await contract.addAccountAdmin(
        2, // timestamp
        2, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genAddAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )

      await contract.setAccountMultiSigThreshold(
        3, // timestamp
        3, // txID
        accID, // accountID
        2, // multiSigThreshold
        salt,
        [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
      )
      expectToThrowAsync(
        contract.setAccountMultiSigThreshold(
          3, // timestamp
          3, // txID
          accID, // accountID
          2, // multiSigThreshold
          salt,
          [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
        )
      )
    })
  })

  describe('Security - Prevent Replay Attack', function () {
    it('Should not allow updating replaying update multisig threshold', async function () {
      const w1 = wallet()
      const w2 = wallet()

      const accID = 1
      const salt = nonce()
      await contract.createSubAccount(
        1, // timestamp
        1, // txID
        accID, // accountID
        w1.address, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        salt,
        [genCreateSubAccountSig(w1, accID, w1.address, 2, 3, salt)] // signature
      )

      await contract.addAccountAdmin(
        2, // timestamp
        2, // txID
        accID, // accountID
        w2.address, // signer
        salt,
        [genAddAccountAdminSig(w1, accID, w2.address, salt)] // signature
      )

      await contract.setAccountMultiSigThreshold(
        3, // timestamp
        3, // txID
        accID, // accountID
        2, // multiSigThreshold
        salt,
        [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
      )
      expectToThrowAsync(
        contract.setAccountMultiSigThreshold(
          3, // timestamp
          3, // txID
          accID, // accountID
          2, // multiSigThreshold
          salt,
          [genSetAccountMultiSigThresholdSig(w1, accID, 2, salt)] // signature
        )
      )
    })
  })
})
