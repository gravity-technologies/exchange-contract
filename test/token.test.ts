import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('Exchange', function () {
    it('Should return hi', async function () {
        const contract = await ethers.deployContract('GRVTExchange')
        expect(await contract.hello()).to.equal('hi')
    })
})
