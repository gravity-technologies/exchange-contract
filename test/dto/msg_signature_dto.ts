interface SignatureDTO {
  // The address (public key) of the wallet signing the payload
  signer: string
  // Signature R
  r: string
  // Signature S
  s: string
  // Signature V
  v: number
  // Timestamp after which this signature expires, expressed in unix nanoseconds. Must be capped at 30 days
  expiration: number
  // Users can randomly generate this value, used as a signature deconflicting key.
  // ie. You can send the same exact instruction twice with different nonces.
  // When the same nonce is used, the same payload will generate the same signature.
  // Our system will consider the payload a duplicate, and ignore it.
  nonce: number
}
