export const CurrencyToEnum: { [cur: string]: number } = {
  UNSPECIFIED: 0,
  USD: 1,
  USDC: 2,
  USDT: 3,
  ETH: 4,
  BTC: 5,
}

export const KindToEnum: { [kind: string]: number } = {
  UNSPECIFIED: 0,
  PERPETUAL: 1,
  FUTURE: 2,
  CALL: 3,
  PUT: 4,
  SPOT: 5,
  SETTLEMENT: 6,
  RATE: 7,
}

function getLSB(val: bigint, shift: number) {
  return Number((val >> BigInt(shift)) & BigInt(0xff))
}

export const toAssetID = ({
  Kind,
  Underlying,
  Quote,
  Expiration,
  StrikePrice,
}: {
  Kind: string
  Underlying: string
  Quote: string
  Expiration: bigint
  StrikePrice: bigint
}) => {
  let msg = new Uint8Array()
  const kind = KindToEnum[Kind ?? "UNSPECIFIED"]
  const u = CurrencyToEnum[Underlying ?? "UNSPECIFIED"]
  const q = CurrencyToEnum[Quote ?? "UNSPECIFIED"]

  switch (Kind) {
    case "SPOT":
    case "RATE":
    case "SETTLEMENT":
      msg = new Uint8Array(2)
      msg[1] = kind
      msg[0] = u
      return msg
    case "PERPETUAL":
      msg = new Uint8Array(3)
      msg[2] = kind
      msg[1] = u
      msg[0] = q
      return msg
    case "FUTURE":
      msg = new Uint8Array(12)
      msg[11] = kind
      msg[10] = u
      msg[9] = q
      msg[8] = 0 // Saving a byte for future use
      msg[7] = getLSB(Expiration, 0)
      msg[6] = getLSB(Expiration, 8)
      msg[5] = getLSB(Expiration, 16)
      msg[4] = getLSB(Expiration, 24)
      msg[3] = getLSB(Expiration, 32)
      msg[2] = getLSB(Expiration, 40)
      msg[1] = getLSB(Expiration, 48)
      msg[0] = getLSB(Expiration, 56)
      return msg
    case "CALL":
    case "PUT":
      msg = new Uint8Array(20)
      msg[19] = kind
      msg[18] = u
      msg[17] = q
      msg[16] = 0 // Saving a byte for future use
      msg[15] = getLSB(Expiration, 0)
      msg[14] = getLSB(Expiration, 8)
      msg[13] = getLSB(Expiration, 16)
      msg[12] = getLSB(Expiration, 24)
      msg[11] = getLSB(Expiration, 32)
      msg[10] = getLSB(Expiration, 40)
      msg[9] = getLSB(Expiration, 48)
      msg[8] = getLSB(Expiration, 56)
      msg[7] = getLSB(StrikePrice, 0)
      msg[6] = getLSB(StrikePrice, 8)
      msg[5] = getLSB(StrikePrice, 16)
      msg[4] = getLSB(StrikePrice, 24)
      msg[3] = getLSB(StrikePrice, 32)
      msg[2] = getLSB(StrikePrice, 40)
      msg[1] = getLSB(StrikePrice, 48)
      msg[0] = getLSB(StrikePrice, 56)
      return msg
  }
  // This should never happen
  return msg
}
