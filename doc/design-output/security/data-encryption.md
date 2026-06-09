# Data Encryption

Last updated: 2026-06-08
Scope: how Nodl encrypts tenant-scoped user content in transit and at rest.

Implements [user story: Data Encryption](../../design-input/user-stories/2026-06-08%20data-encryption.md).

This document records **which categories of data are encrypted, at which layers**,
without exposing secrets. It is the authoritative reference for the security page
copy and for operators.

## Summary

| Data | In transit | At rest |
|---|---|---|
| Browser ↔ app traffic (pages, Turbo, Action Cable) | TLS + HSTS | n/a |
| App ↔ subprocessors (Mistral, Google) | HTTPS / WSS | n/a |
| Recording transcripts (text + diarized segments) | TLS | AES (Active Record Encryption) |
| Generated documents (content + title) | TLS | AES (Active Record Encryption) |
| Recording titles | TLS | AES (Active Record Encryption) |
| Workspace name & transformer format settings (name, instructions) | TLS | AES (Active Record Encryption) |
| Uploaded audio + transformer example files (blobs) | TLS | AES (per-blob key, EncryptedDisk) |

## In transit

- **Browser ↔ app.** Production forces TLS for all traffic and emits HSTS with
  secure cookies (`config.force_ssl`, `config.assume_ssl` in
  `config/environments/production.rb`). TLS is terminated at the reverse proxy /
  Cloudflare in front of the app. Action Cable (live transcript updates) rides the
  same origin, so it is served over `wss://` whenever the page is HTTPS.
- **App ↔ subprocessors.** All outbound calls that carry user data use encrypted
  transport: transcription and generation to Mistral (`https://api.mistral.ai`,
  `lib/nodl/providers/mistral_client.rb`), realtime transcription over
  `wss://api.mistral.ai` (`lib/nodl/providers/mistral_realtime_client.rb`), and
  Google generation/upload over HTTPS (`lib/nodl/providers/gemini_client.rb`).
- **Health checks.** `/up`, `/healthz`, and `/readyz` are excluded from the
  HTTP→HTTPS redirect and host-authorization checks (`ssl_options`,
  `host_authorization` in production.rb) so operations probes keep working without
  weakening user-facing TLS.

## At rest — database (Active Record Encryption)

Sensitive columns are encrypted with Rails' built-in Active Record Encryption
(AES-256-GCM, non-deterministic). Ciphertext is what is stored in PostgreSQL and
what appears in dumps/backups; decryption is transparent at the application layer.

Encrypted columns:

- `recording_sessions`: `transcript_text`, `transcript_segments`, `title`
- `documents`: `content`, `title`
- `transformer_profiles`: `instructions`, `name`
- `workspaces`: `name`

`transcript_segments` was migrated from `jsonb` to `text` (encrypted attributes
persist as a string) and is JSON-serialized in the model.

Deliberately **not** encrypted, with rationale:

- Identifiers used for lookups/indexes/ordering: `workspaces.slug`,
  `transformer_profiles.handle`, `recording_sessions.transformer_handle`.
  Encryption is non-deterministic, so these could no longer be queried or ordered.
- `recording_sessions.error_message` (truncated diagnostic text),
  `recording_sessions.work_path` (a server-side path), and
  `recording_sessions.waveform_peaks` (derived audio amplitudes for the UI, not
  content).

Out of scope for this story and left as-is: `users` (email is needed for login
lookups; passwords are already one-way hashed via `has_secure_password`) and
`admin_audit_event` (audit logs are governed by existing access controls).

### Keys

The three Active Record Encryption keys live under `active_record_encryption` in
Rails encrypted credentials (`config/credentials.yml.enc`), decrypted in
production via `RAILS_MASTER_KEY`. The test suite uses fixed throwaway keys set in
`config/environments/test.rb` so CI never depends on the master key.

## At rest — blobs (EncryptedDisk)

Uploaded audio (`original_audio`, `normalized_audio`) and transformer example
files are stored through the `EncryptedDisk` service from the
`active_storage_encryption` gem (`config/storage.yml`). Every blob is encrypted
with its **own** random key (AES-256-GCM); just having the storage volume is not
enough to read any file.

- The per-blob key is stored in `active_storage_blobs.encryption_key`, which is
  itself wrapped with Active Record Encryption — so a database dump never reveals
  blob keys either.
- `private_url_policy: stream` serves decrypted bytes through the mounted
  `ActiveStorageEncryption::Engine` (`/active-storage-encryption`), preserving
  HTTP Range requests so audio playback and seeking work normally for authorized
  workspace members. `rails_blob_path` continues to work unchanged.
- Attachments are pinned to the encrypted service via
  `config.x.attachment_service` so a per-blob key is always generated.

## Operational notes

- **Backfilling existing data.** `rails encryption:backfill` re-saves existing
  rows so their columns are encrypted in place (idempotent).
  `rails encryption:reencrypt_blobs` reads each legacy plaintext blob, rewrites it
  encrypted with a fresh per-blob key, and removes the plaintext copy (idempotent).
  `config.active_record.encryption.support_unencrypted_data` is `false`
  (in `config/application.rb`): reading a plaintext value from an encrypted column
  raises instead of being tolerated. Operators upgrading an instance that still
  holds pre-encryption data set it to `true`, run both backfill tasks, then flip
  it back and redeploy.
- **Abandoned/failed uploads.** `PurgeUnattachedBlobsJob` runs daily
  (`config/recurring.yml`) and purges unattached blobs older than one day. On the
  EncryptedDisk service these orphans are ciphertext regardless, so no readable
  fragments persist.
- **Key rotation / no lockout.** Active Record Encryption supports a list of keys:
  add a new key, keep the previous one so existing ciphertext still decrypts,
  re-encrypt, then retire the old key. Rotating the Active Record Encryption key
  re-wraps each per-blob `encryption_key` without rewriting blob ciphertext, so
  blob data is never re-encrypted on key rotation and users are never locked out.
  Never drop an old key before data encrypted with it has been re-encrypted.

## Out of scope (per the user story)

- End-to-end encryption where only the user holds the keys (Nodl must process
  transcripts and documents to provide the product).
- Customer-managed / bring-your-own encryption keys.
- Encrypting operational telemetry or audit logs beyond existing privacy and
  access controls.
