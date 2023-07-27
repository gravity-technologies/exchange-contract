import { expect } from 'chai'

export async function expectToThrowAsync(promise: Promise<any>) {
  let error = null
  try {
    await promise
  } catch (err) {
    error = err
  }
  expect(error).to.be.an('Error')
}

export async function expectNotToThrowAsync(promise: Promise<any>) {
  let error = null
  try {
    await promise
  } catch (err) {
    error = err
  }
  expect(error).to.be.null
}
