import { Contract } from 'ethers'
import { ethers } from 'hardhat'
import { expectNotToThrowAsync, expectToThrowAsync } from './util'

function getAddress(): string {
  return ethers.Wallet.createRandom().address
}

describe('API - Account', function () {
  let contract: Contract

  beforeEach(async () => {
    contract = await ethers.deployContract('GRVTExchange')
  })

  // TODO: fix this test
  describe('CreateSubAccount', function () {
    it('Success', async function () {
      const subID = getAddress()
      const signer = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })

    it('Error if account already exists', async function () {
      const subID = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
      expectToThrowAsync(
        contract.CreateSubAccount(
          2, // timestamp
          2, // txID
          1, // accountID
          subID, // subAccountID
          2, // quoteCurrency: USDC
          3, // marginType: PORTFOLIO_CROSS_MARGIN
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('AddAccountAdmin', function () {
    it('Success', async function () {
      const subID1 = getAddress()
      const subID2 = getAddress()
      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID1, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
      await contract.AddAccountAdmin(
        2, // timestamp
        2, // txID
        1, // accountID
        subID2, // signer
        [{ signer: subID2, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })
    it('Reject if account does not exist', async function () {
      const subID1 = getAddress()
      expectToThrowAsync(
        contract.AddAccountAdmin(
          2, // timestamp
          2, // txID
          1, // accountID
          subID1, // signer
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
    it('No-op if admin address already exists', async function () {
      const subID1 = getAddress()
      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID1, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
      expectNotToThrowAsync(
        contract.AddAccountAdmin(
          2, // timestamp
          2, // txID
          1, // accountID
          subID1, // signer
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('RemoveAccountAdmin', function () {
    it('Success', async function () {
      const subID1 = getAddress()
      const newSigner = getAddress()
      const subID2 = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID1, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      await contract.AddAccountAdmin(
        2, // timestamp
        2, // txID
        1, // accountID
        newSigner, // signer
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      await contract.RemoveAccountAdmin(
        3, // timestamp
        3, // txID
        1, // accountID
        newSigner, // signer
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })

    it('Error if account does not exist', async function () {
      const subID1 = getAddress()

      expectToThrowAsync(
        contract.RemoveAccountAdmin(
          2, // timestamp
          2, // txID
          1, // accountID
          subID1, // signer
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })

    it('Error if admin address does not exist', async function () {
      const subID1 = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID1, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      expectToThrowAsync(
        contract.RemoveAccountAdmin(
          2, // timestamp
          2, // txID
          1, // accountID
          subID1, // signer
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('AddWithdrawalAddress', function () {
    it('Success', async function () {
      const subID = getAddress()
      const withdrawalAddress = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
      await contract.AddWithdrawalAddress(
        2, // timestamp
        2, // txID
        1, // accountID
        withdrawalAddress,
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })

    it('Reject if account does not exist', async function () {
      const withdrawalAddress = getAddress()

      expectToThrowAsync(
        contract.AddWithdrawalAddress(
          1, // timestamp
          1, // txID
          1, // accountID
          withdrawalAddress,
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })

    it('Reject if withdrawal address already exists', async function () {
      const subID = getAddress()
      const withdrawalAddress = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      await contract.AddWithdrawalAddress(
        2, // timestamp
        2, // txID
        1, // accountID
        withdrawalAddress,
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      expectToThrowAsync(
        contract.AddWithdrawalAddress(
          3, // timestamp
          3, // txID
          1, // accountID
          withdrawalAddress,
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('RemoveWithdrawalAddress', function () {
    it('Success', async function () {
      const subID = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      const withdrawalAddress = getAddress()
      await contract.AddWithdrawalAddress(
        2, // timestamp
        2, // txID
        1, // accountID
        withdrawalAddress, // withdrawalAddress
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      await contract.RemoveWithdrawalAddress(
        3, // timestamp
        3, // txID
        1, // accountID
        withdrawalAddress, // withdrawalAddress
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })

    it('Error if account does not exist', async function () {
      const withdrawalAddress = getAddress()

      expectToThrowAsync(
        contract.RemoveWithdrawalAddress(
          2, // timestamp
          2, // txID
          1, // accountID
          withdrawalAddress, // withdrawalAddress
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })

    it('Error if withdrawal address does not exist', async function () {
      // Create an account explicitly for this test
      const subID = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      const withdrawalAddress1 = getAddress()
      const withdrawalAddress2 = getAddress()

      // Add withdrawal address explicitly for this test
      await contract.AddWithdrawalAddress(
        2, // timestamp
        2, // txID
        1, // accountID
        withdrawalAddress1, // withdrawalAddress
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      expectToThrowAsync(
        contract.RemoveWithdrawalAddress(
          3, // timestamp
          3, // txID
          1, // accountID
          withdrawalAddress2, // withdrawalAddress
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('AddTransferSubAccount', function () {
    it('Success', async function () {
      // Create an account explicitly for this test
      const subID = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      const transferSubAccount = getAddress()

      await contract.AddTransferSubAccount(
        2, // timestamp
        2, // txID
        1, // accountID
        transferSubAccount, // transferSubAccount
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      // Perform necessary assertions or validations for a successful execution
    })

    it('Reject if account does not exist', async function () {
      const transferSubAccount = getAddress()

      expectToThrowAsync(
        contract.AddTransferSubAccount(
          2, // timestamp
          2, // txID
          1, // accountID
          transferSubAccount, // transferSubAccount
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })

    it('No-op if transfer subaccount already exists', async function () {
      const subID = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      const transferSubAccount = getAddress()

      // Add transfer subaccount explicitly for this test
      await contract.AddTransferSubAccount(
        2, // timestamp
        2, // txID
        1, // accountID
        transferSubAccount, // transferSubAccount
        [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      expectNotToThrowAsync(
        contract.AddTransferSubAccount(
          3, // timestamp
          3, // txID
          1, // accountID
          transferSubAccount, // transferSubAccount
          [{ signer: subID, expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })

  describe('SetAccountMultiSigThreshold', function () {
    it('Success', async function () {
      const subID1 = getAddress()
      const subID2 = getAddress()

      await contract.CreateSubAccount(
        1, // timestamp
        1, // txID
        1, // accountID
        subID1, // subAccountID
        2, // quoteCurrency: USDC
        3, // marginType: PORTFOLIO_CROSS_MARGIN
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
      await contract.AddAccountAdmin(
        2, // timestamp
        2, // txID
        1, // accountID
        subID2, // signer
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )

      await contract.SetAccountMultiSigThreshold(
        3, // timestamp
        3, // txID
        1, // accountID
        1, // multiSigThreshold
        [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
      )
    })

    it('Reject if threshold = 0', async function () {
      // TODO: add 1 admin here
      expectToThrowAsync(
        contract.SetAccountMultiSigThreshold(
          2, // timestamp
          2, // txID
          1, // accountID
          0, // multiSigThreshold
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })

    it('Reject if threshold > number of admins', async function () {
      expectToThrowAsync(
        contract.SetAccountMultiSigThreshold(
          2, // timestamp
          2, // txID
          1, // accountID
          3, // multiSigThreshold
          [{ signer: getAddress(), expiration: 0, R: 0, S: 0, V: 0 }] // signature
        )
      )
    })
  })
})
