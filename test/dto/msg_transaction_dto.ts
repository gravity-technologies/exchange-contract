interface MsgTransactionDTO {
  traceID: number
  txID: number
  time: number
  type: TransactionType
  createAccount: CreateAccountDTO
}

interface CreateAccountDTO {
  Account: string
  Signature: string
}
