require "digest"
require "json"
require "nodl/integrity/seal_result"
require "nodl/integrity/tsa_client"

module Nodl
  module Integrity
    class RecordingIntegrityService
      class << self
        def seal_blob(blob, tsa_client: TsaClient.from_env)
          bytes = blob.download
          digest = Digest::SHA256.digest(bytes)
          hash_sha256 = digest.unpack1("H*")
          hashed_at = Time.current
          proof = tsa_client.seal_digest(
            digest: digest,
            hash_algorithm: RecordingIntegrityRecord::HASH_ALGORITHM_SHA256
          )

          SealResult.new(
            hash_sha256: hash_sha256,
            hash_algorithm: RecordingIntegrityRecord::HASH_ALGORITHM_SHA256,
            hashed_at: hashed_at,
            tsa_status: proof.status,
            tsa_provider: proof.provider,
            tsa_authority: proof.authority,
            tsa_proof_format: proof.proof_format,
            tsa_proof_blob: proof.proof_blob,
            tsa_timestamp: proof.timestamp,
            tsa_error: proof.error
          )
        end

        def upsert!(recording_session, result)
          record = recording_session.integrity_record || recording_session.build_integrity_record
          record.update!(
            hash_sha256: result.hash_sha256,
            hash_algorithm: result.hash_algorithm,
            hashed_at: result.hashed_at,
            tsa_status: result.tsa_status,
            tsa_provider: result.tsa_provider,
            tsa_authority: result.tsa_authority,
            tsa_proof_format: result.tsa_proof_format,
            tsa_proof_blob: result.tsa_proof_blob,
            tsa_timestamp: result.tsa_timestamp,
            tsa_error: result.tsa_error
          )
          record
        end

        def certificate_payload(recording_session, audio_bytes:)
          record = recording_session.integrity_record
          stored_hash = record&.hash_sha256
          hash_matches = if stored_hash.present?
            Digest::SHA256.hexdigest(audio_bytes) == stored_hash
          end

          {
            recording_session_id: recording_session.id,
            original_filename: recording_session.original_audio_download_filename,
            integrity_hash_sha256: stored_hash,
            integrity_hash_algorithm: record&.hash_algorithm,
            integrity_hashed_at_utc: iso8601(record&.hashed_at),
            integrity_tsa_status: record&.tsa_status,
            integrity_tsa_provider: record&.tsa_provider,
            integrity_tsa_authority: record&.tsa_authority,
            integrity_tsa_proof_format: record&.tsa_proof_format,
            integrity_tsa_timestamp: iso8601(record&.tsa_timestamp),
            integrity_tsa_proof_blob: record&.tsa_proof_blob,
            integrity_tsa_error: record&.tsa_error,
            integrity_hash_matches_exported_file: hash_matches
          }
        end

        private

        def iso8601(value)
          value&.utc&.iso8601
        end
      end
    end
  end
end
