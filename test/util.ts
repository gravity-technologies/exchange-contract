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

export function buf(s: string): Buffer {
  return Buffer.from(s.substring(2), 'hex')
}

export function getTimestamp(addDays: number = 10): number {
  const deltaInMs = addDays * 24 * 60 * 60 * 1000
  return Math.floor((Date.now() + deltaInMs) * 1000)
}
