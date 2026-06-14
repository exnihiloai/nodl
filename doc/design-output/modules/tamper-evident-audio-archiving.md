# Tamper-Evident Audio Archiving

Status: implemented design output

## Summary

Tamper-evident audio archiving adds an optional integrity proof for newly created recording sessions. When `User#integrity_sealing_enabled` is true, Nodl hashes the `RecordingSession#original_audio` blob with SHA-256, sends only the digest to an RFC 3161 timestamp service, stores the signed timestamp response, and exposes the result on the recording page.

The feature is additive and fail-open: transcription and document generation do not depend on timestamping.

## Data Model

- `users.integrity_sealing_enabled` controls the feature per user. It defaults to `false` and is only editable through the admin user detail page.
- `recording_integrity_records` stores one integrity row per recording session:
  - `hash_sha256`, `hash_algorithm`, `hashed_at`
  - `tsa_status`: `sealed`, `failed`, or `pending_config`
  - `tsa_provider`, `tsa_authority`, `tsa_proof_format`, `tsa_proof_blob`, `tsa_timestamp`, `tsa_error`
- The integrity record is deleted with its recording session.

## TSA Flow

`SealRecordingIntegrityJob` runs after upload creation or microphone finalization when the creator has sealing enabled and original audio is attached.

The job:

1. downloads the original Active Storage blob bytes;
2. computes a SHA-256 digest;
3. builds an RFC 3161 `TimeStampReq`;
4. posts the request to the configured TSA endpoint;
5. stores the hash and timestamp proof metadata.

Configuration:

- `INTEGRITY_TSA_PROVIDER`, default `rfc3161_freetsa`
- `INTEGRITY_TSA_URL`, default `https://freetsa.org/tsr` outside test and blank in test
- `INTEGRITY_TSA_TIMEOUT_SECONDS`, default `8`
- `INTEGRITY_TSA_RETRY_COUNT`, default `1`
- `INTEGRITY_TSA_RETRY_BACKOFF_SECONDS`, default `0.5`

Only the hash digest is sent to the TSA. The audio file remains in Nodl storage.

## Failure And Retry

Timestamp failures never mark a recording failed. If the TSA URL is blank or the provider is unsupported, the row is stored as `pending_config`. Network or TSA response failures store `failed`.

`RetryRecordingIntegritySealsJob` is scheduled in production through Solid Queue recurring jobs. It retries records with `failed` or `pending_config` status when the creator still has sealing enabled and original audio still exists.

## User Export

The recording page shows integrity status only when the creator has sealing enabled. A sealed recording exposes an integrity archive ZIP containing:

- the original audio file using the same bytes and filename rules as the standalone original-audio download;
- `integrity-certificate.json`.

The certificate includes the recorded hash, timestamp proof fields, and `integrity_hash_matches_exported_file`. That field is computed during ZIP generation by re-hashing the bundled audio:

- `true`: bundled audio matches the stored hash;
- `false`: bundled audio differs from the stored hash;
- `null`: no stored hash was available.

## Manual Verification

A reviewer can independently verify a ZIP export by:

1. computing SHA-256 over the exported audio file and comparing it to `integrity_hash_sha256`;
2. decoding `integrity_tsa_proof_blob` from base64 into a `.tsr` file;
3. inspecting or verifying the timestamp response with OpenSSL and the TSA certificate chain.

Example commands:

```sh
sha256sum recording.mp3
jq -r '.integrity_tsa_proof_blob' integrity-certificate.json | base64 --decode > proof.tsr
openssl ts -reply -in proof.tsr -text
openssl ts -verify -data recording.mp3 -in proof.tsr -CAfile tsa-root.pem -untrusted tsa-intermediates.pem
```

Nodl does not claim legal notarization or guaranteed admissibility. This is a technical integrity proof for the original audio bytes.
