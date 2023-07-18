const KeyMirror = require('keymirror')
const { EIP712Domain, domain } = require('./common.js')

const Primary = KeyMirror({
  // Account
  AddAccountAdminPayload: 0,
  AddTransferSubAccountPayload: 0,
  AddWithdrawalAddressPayload: 0,
  CreateSubAccountPayload: 0,
  RemoveAccountAdminPayload: 0,
  RemoveTransferSubAccountPayload: 0,
  RemoveWithdrawalAddressPayload: 0,
  SetAccountMultiSigThresholdPayload: 0,

  // Account Recovery
  AddAccountGuardianPayload: 0,
  RemoveAccountGuardianPayload: 0,

  // SubAccount
  AddSubAccountSignerPayload: 0,
  RemoveSubAccountSignerPayload: 0,
  SetSubAccountMarginTypePayload: 0,
  SetSubAccountSignerPermissionsPayload: 0,

  // Trade
})

// -------------- Account --------------
const CreateSubAccountPayload = {
  primaryType: Primary.CreateSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.CreateSubAccountPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'subAccountID', type: 'address' },
      { name: 'quoteCurrency', type: 'uint8' },
      { name: 'marginType', type: 'uint8' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const SetAccountMultiSigThresholdPayload = {
  primaryType: Primary.SetAccountMultiSigThresholdPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetAccountMultiSigThresholdPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'multiSigThreshold', type: 'uint8' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const AddAccountAdminPayload = {
  primaryType: Primary.AddAccountAdminPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddAccountAdminPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'signer', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const RemoveAccountAdminPayload = {
  primaryType: Primary.RemoveAccountAdminPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveAccountAdminPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'signer', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const AddWithdrawalAddressPayload = {
  primaryType: Primary.AddWithdrawalAddressPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddWithdrawalAddressPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'withdrawalAddress', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const RemoveWithdrawalAddressPayload = {
  primaryType: Primary.RemoveWithdrawalAddressPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveWithdrawalAddressPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'withdrawalAddress', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const AddTransferSubAccountPayload = {
  primaryType: Primary.AddTransferSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddTransferSubAccountPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'transferSubAccount', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const RemoveTransferSubAccountPayload = {
  primaryType: Primary.RemoveTransferSubAccountPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveTransferSubAccountPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'transferSubAccount', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const AddAccountGuardianPayload = {
  primaryType: Primary.AddAccountGuardianPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddAccountGuardianPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'signer', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const RemoveAccountGuardianPayload = {
  primaryType: Primary.RemoveAccountGuardianPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveAccountGuardianPayload]: [
      { name: 'accountID', type: 'uint32' },
      { name: 'signer', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

// -------------- SubAccount --------------
const SetSubAccountMarginTypePayload = {
  primaryType: Primary.SetSubAccountMarginTypePayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetSubAccountMarginTypePayload]: [
      { name: 'subAccountID', type: 'address' },
      { name: 'marginType', type: 'uint8' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const AddSubAccountSignerPayload = {
  primaryType: Primary.AddSubAccountSignerPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.AddSubAccountSignerPayload]: [
      { name: 'subAccountID', type: 'address' },
      { name: 'signer', type: 'address' },
      { name: 'permissions', type: 'uint16' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}
const SetSubAccountSignerPermissionsPayload = {
  primaryType: Primary.SetSubAccountSignerPermissionsPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.SetSubAccountSignerPermissionsPayload]: [
      { name: 'subAccountID', type: 'address' },
      { name: 'signer', type: 'address' },
      { name: 'permissions', type: 'uint64' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

const RemoveSubAccountSignerPayload = {
  primaryType: Primary.RemoveSubAccountSignerPayload,
  domain,
  types: {
    EIP712Domain,
    [Primary.RemoveSubAccountSignerPayload]: [
      { name: 'subAccountID', type: 'address' },
      { name: 'signer', type: 'address' },
      { name: 'nonce', type: 'uint32' },
    ],
  },
}

module.exports = {
  // Account
  CreateSubAccountPayload,
  AddAccountAdminPayload,
  AddTransferSubAccountPayload,
  AddWithdrawalAddressPayload,
  CreateSubAccountPayload,
  RemoveAccountAdminPayload,
  RemoveTransferSubAccountPayload,
  RemoveWithdrawalAddressPayload,
  SetAccountMultiSigThresholdPayload,

  // Account Recovery
  AddAccountGuardianPayload,
  RemoveAccountGuardianPayload,

  // SubAccount
  AddSubAccountSignerPayload,
  RemoveSubAccountSignerPayload,
  SetSubAccountMarginTypePayload,
  SetSubAccountSignerPermissionsPayload,
}
