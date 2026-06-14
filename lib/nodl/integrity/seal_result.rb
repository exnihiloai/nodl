module Nodl
  module Integrity
    SealResult = Struct.new(
      :hash_sha256,
      :hash_algorithm,
      :hashed_at,
      :tsa_status,
      :tsa_provider,
      :tsa_authority,
      :tsa_proof_format,
      :tsa_proof_blob,
      :tsa_timestamp,
      :tsa_error,
      keyword_init: true
    )

    TimestampProofResult = Struct.new(
      :status,
      :provider,
      :authority,
      :proof_format,
      :proof_blob,
      :timestamp,
      :error,
      keyword_init: true
    )
  end
end
