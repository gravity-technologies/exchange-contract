import { expect } from 'chai'
import { ethers } from 'hardhat'
import { randomBytes } from 'crypto'

describe('Exchange', function () {
  it('Should return hi', async function () {
    const contract = await ethers.deployContract('GRVTExchange')
    expect(await contract.hello()).to.equal('hi')
  })

  it('Should allow adding and finding addresses', async function () {
    let lastAddr = ''
    const contract = await ethers.deployContract('GRVTExchange')
    for (let i = 0; i < 100; i++) {
      const pk = ethers.Wallet.createRandom().address
      // Test add address
      await contract.addAddress(pk)
      lastAddr = pk
    }

    // Test find address
    expect(await contract.findAddress(lastAddr)).to.equal(99)
  })
})
