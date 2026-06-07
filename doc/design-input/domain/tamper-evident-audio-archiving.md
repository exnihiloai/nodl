# Tamper-Evident Audio Archiving — Design Document

> Status: **Approved** · Date: 2026-06-07 · Type: design-input
>
> Related user story: [../user-stories/2026-06-07 tamper-evident-audio-archiving.md](../user-stories/2026-06-07%20tamper-evident-audio-archiving.md)

## 1. Summary

Nodl stores original audio recordings and produces transcripts and documents from them. Today, Active Storage keeps a blob checksum for internal integrity, but that checksum is under Nodl’s control and is not independently verifiable by a third party.

This design adds **tamper-evident audio archiving**: when enabled for a user, each new recording session’s **original audio file** receives a **SHA-256 fingerprint** and an **externally signed timestamp proof** (RFC 3161 Time-Stamp Protocol). Together they demonstrate that the file existed in exactly that form at a specific time and has not been altered since — without exposing the audio content to the timestamp authority.

The feature is **opt-in per user**, **off by default**, and **admin-controlled**. It must not position Nodl as a healthcare or medical product; wording stays domain-neutral (recordings, conversations, integrity proof).

---

## 2. Goals

- **Cryptographic integrity proof** for the original audio attached to a `RecordingSession`.
- **Trusted timestamp** from an external Time-Stamp Authority (TSA), not merely Nodl’s database clock.
- **Third-party verifiable** evidence: a user (or auditor) can re-hash the exported file and validate the stored timestamp token offline.
- **Non-blocking pipeline**: transcription and document generation succeed even if sealing fails.
- **Admin-only enablement** per user; ordinary users cannot toggle the feature.
- **Privacy-preserving**: only a hash leaves Nodl for timestamping; the audio itself stays in encrypted storage.

---

## 3. Non-goals

- **Legal notarization or guaranteed courtroom admissibility.** Nodl provides a technical integrity proof, not legal advice or a regulated notarial service.
- **Healthcare / medical product positioning.** No clinical, patient, or provider-specific language in product copy or data models.
- **Sealing normalized or derived audio.** The proof covers `original_audio` only, not the optional normalized MP3 used internally for transcription.
- **Sealing transcripts or generated documents** in phase 1. Scope is the audio blob only.
- **Blockchain anchoring** in phase 1. RFC 3161 TSA is sufficient and simpler.
- **Automatic re-sealing** when a blob is replaced. If `original_audio` changes after sealing, the existing record becomes stale; re-sealing is a later enhancement.
- **Per-workspace billing or metering** for timestamp calls in phase 1.

---

## 4. Locked design decisions

| # | Decision | Rationale |
|---|---|---|
| **D1** | **Hash algorithm: SHA-256** | Industry standard; matches common TSA support and auditor expectations. |
| **D2** | **Proof format: RFC 3161 (`rfc3161-tsr`)** | Established trusted-timestamp standard; verifiable with OpenSSL and standard tooling. |
| **D3** | **Seal target: `original_audio` blob bytes** | The user-facing “source of truth” recording; normalization must not change what is proven. |
| **D4** | **Sealing runs after audio attach, in a separate job** | Upload/finalize and `ProcessRecordingSessionJob` stay fast; TSA latency and retries are isolated. |
| **D5** | **Sealing failure never fails the session** | Same resilience pattern as the primary processing pipeline: integrity is additive, not a gate. |
| **D6** | **Feature flag on `User`, default off, admin-only** | Matches the user story; avoids surprise cost and keeps the default product simple. |
| **D7** | **Store full TSA response blob (base64) in DB** | Enables offline verification and export without re-contacting the TSA. |
| **D8** | **HTTP TSA provider, configurable via env** | Start with a public RFC 3161 endpoint (e.g. FreeTSA) for development; swap to a qualified EU TSA in production when needed. |
| **D9** | **1:1 `RecordingIntegrityRecord` per session** | Clear ownership; upsert on retry; easy to expose in UI and exports. |

---

## 5. Problem statement

A checksum stored only inside Nodl proves nothing to an external party. If someone questions whether a recording was edited after capture, Nodl needs evidence that:

1. A specific file content existed at time **T**.
2. Any change to the file — even a single bit — would produce a different hash and invalidate the proof.

An external TSA signs the hash together with a trusted clock. Nodl cannot retroactively forge that signature without the TSA’s private key.

---

## 6. System overview

### 6.1 High-level flow

```text
                         ┌────────────── browser ──────────────┐
  microphone / upload ──▶│ attach original_audio to session      │
                         └──────────────────┬────────────────────┘
                                            │
                                            ▼
                         ProcessRecordingSessionJob (existing)
                         transcribe → document → completed
                                            │
                         (parallel, if user flag enabled)
                                            ▼
                         SealRecordingIntegrityJob
                           1. read original_audio bytes
                           2. SHA-256 → hex digest
                           3. POST digest to TSA (RFC 3161)
                           4. upsert RecordingIntegrityRecord
                                            │
                                            ▼
                         recording session page: status + JSON certificate download
```

### 6.2 When sealing runs

| Entry path | Trigger |
|---|---|
| **File upload** | After `RecordingSession` is saved with `original_audio` attached → enqueue `SealRecordingIntegrityJob` if creator has sealing enabled. |
| **Microphone recording** | After `finalize` attaches the continuous clip and enqueues `ProcessRecordingSessionJob` → enqueue sealing job on the same condition. |

Sealing does **not** wait for transcription to finish. It only requires a stable `original_audio` attachment.

### 6.3 Status values

| `tsa_status` | Meaning |
|---|---|
| `sealed` | TSA returned a valid timestamp token; proof blob stored. |
| `failed` | Hash computed, but TSA call failed after retries; error message stored. |
| `pending_config` | Hash computed, but TSA URL/provider not configured (typical in test). |

Hash fields (`hash_sha256`, `hashed_at`) are populated whenever the file was read successfully, even when TSA sealing did not succeed.

---

## 7. Data model

### 7.1 `recording_integrity_records`

One row per `RecordingSession` (unique index on `recording_session_id`).

| Column | Type | Notes |
|---|---|---|
| `recording_session_id` | FK, unique | `on_delete: :cascade` |
| `hash_sha256` | string(64) | Hex-encoded SHA-256 of original audio bytes |
| `hash_algorithm` | string(20) | Always `sha256` in phase 1 |
| `hashed_at` | datetime (UTC) | When Nodl computed the hash |
| `tsa_status` | string(30), indexed | `sealed` / `failed` / `pending_config` |
| `tsa_provider` | string(80) | e.g. `rfc3161_freetsa` |
| `tsa_authority` | string(255) | Hostname or CA label of the TSA |
| `tsa_proof_format` | string(50) | `rfc3161-tsr` |
| `tsa_proof_blob` | text | Base64-encoded TSA response (TimeStampResp) |
| `tsa_timestamp` | datetime (UTC), nullable | Best-effort from TSA response or HTTP `Date` header |
| `tsa_error` | string(500), nullable | Truncated error when status is `failed` |
| `created_at` / `updated_at` | datetime | Standard Rails timestamps |

### 7.2 Associations

```ruby
class RecordingSession < ApplicationRecord
  has_one :integrity_record, class_name: "RecordingIntegrityRecord", dependent: :destroy
end

class RecordingIntegrityRecord < ApplicationRecord
  belongs_to :recording_session
end
```

### 7.3 User feature flag

Add to `users`:

| Column | Type | Default |
|---|---|---|
| `integrity_sealing_enabled` | boolean | `false` |

Only admins may change this field (Admin UI + strong params + audit event). The sealing job checks `recording_session.creator.integrity_sealing_enabled?`.

---

## 8. Sealing service

### 8.1 Module layout

```text
lib/nodl/integrity/
  der_encoding.rb       # minimal DER helpers for RFC 3161 TimeStampReq
  tsa_client.rb         # HTTP POST to TSA; parse TimeStampResp status
  seal_result.rb        # value object (mirrors IntegritySealResult pattern)
  recording_integrity_service.rb
    .seal_blob(blob)    # compute hash + call TSA
    .upsert!(session, result)
```

Keep OpenSSL-heavy verification in a separate object (`lib/nodl/integrity/proof_verifier.rb`) for tests and future CLI/rake task.

### 8.2 Sealing algorithm

1. Download/read `original_audio` blob bytes via Active Storage (same bytes that were uploaded).
2. `digest = Digest::SHA256.digest(bytes)`; `hash_sha256 = digest.hexdigest`.
3. Build RFC 3161 `TimeStampReq` DER payload (SHA-256 OID `2.16.840.1.101.3.4.2.1`, nonce, `certReq: true`).
4. `POST` to configured TSA URL with headers:
   - `Content-Type: application/timestamp-query`
   - `Accept: application/timestamp-reply`
5. Parse response: PKIStatus `0` (granted) or `1` (grantedWithMods) with a timestamp token present.
6. Store base64(response_body) in `tsa_proof_blob`.
7. Upsert `RecordingIntegrityRecord`.

### 8.3 Retries and timeouts

Environment-driven (defaults shown):

| Variable | Default | Purpose |
|---|---|---|
| `INTEGRITY_TSA_PROVIDER` | `rfc3161_freetsa` | Provider key |
| `INTEGRITY_TSA_URL` | empty in test; `https://freetsa.org/tsr` elsewhere | TSA endpoint |
| `INTEGRITY_TSA_TIMEOUT_SECONDS` | `8` | HTTP timeout |
| `INTEGRITY_TSA_RETRY_COUNT` | `1` | Retries after first failure |
| `INTEGRITY_TSA_RETRY_BACKOFF_SECONDS` | `0.5` | Linear backoff multiplier |

When `INTEGRITY_TSA_URL` is blank, status is `pending_config` but the hash is still stored.

### 8.4 Job

```ruby
class SealRecordingIntegrityJob < ApplicationJob
  queue_as :default

  def perform(recording_session_id)
    session = RecordingSession.find(recording_session_id)
    return unless session.creator.integrity_sealing_enabled?
    return unless session.original_audio.attached?

    result = Nodl::Integrity::RecordingIntegrityService.seal(session.original_audio.blob)
    Nodl::Integrity::RecordingIntegrityService.upsert!(session, result)
  rescue StandardError => e
    Rails.logger.warn("integrity_seal_failed session=#{recording_session_id} error=#{e.message}")
  end
end
```

Enqueue from `RecordingSessionsController#create` (upload path) and `#finalize` (microphone path), and optionally defensively from `RecordingSessionProcessor` if audio was attached elsewhere.

---

## 9. Verification and export

### 9.1 In-app integrity certificate (JSON)

Provide a download on the recording session show page when an integrity record exists:

```json
{
  "recording_session_id": 42,
  "original_filename": "conversation.webm",
  "integrity_hash_sha256": "e3b0c44298fc1c149afb...",
  "integrity_hash_algorithm": "sha256",
  "integrity_hashed_at_utc": "2026-06-07T14:32:11Z",
  "integrity_tsa_status": "sealed",
  "integrity_tsa_provider": "rfc3161_freetsa",
  "integrity_tsa_authority": "freetsa.org",
  "integrity_tsa_proof_format": "rfc3161-tsr",
  "integrity_tsa_timestamp": "2026-06-07T14:32:12Z",
  "integrity_tsa_proof_blob": "MIIHqDADAgEA...",
  "integrity_tsa_error": null,
  "integrity_hash_matches_exported_file": true
}
```

When generating the JSON at download time, Nodl re-reads the blob, recomputes SHA-256, and sets `integrity_hash_matches_exported_file` to `true`, `false`, or `null` (no stored hash).

### 9.2 Manual offline verification

Document for power users (separate guide page, not required for daily use):

1. **Hash check:** `sha256sum exported-audio.webm` must equal `integrity_hash_sha256`.
2. **Timestamp check:** decode `integrity_tsa_proof_blob` from base64 and verify with OpenSSL against the TSA certificate chain (`openssl ts -verify ...`).

Nodl does not need to run full PKIX verification on every page view in phase 1; status display is based on sealing outcome. Optional admin/rake verifier can perform full cryptographic validation.

### 9.3 Future: bulk export

If Nodl adds a GDPR-style data export ZIP later, include the same sidecar JSON next to each audio file and set `integrity_hash_matches_exported_file` the same way. Out of scope for phase 1 unless a data-export feature already exists at implementation time.

---

## 10. UI and admin

### 10.1 Recording session page

When the creator has sealing enabled:

| `tsa_status` | UI |
|---|---|
| `sealed` | Success badge: “Integrity sealed” + UTC timestamp + link “Download integrity certificate (JSON)” |
| `failed` | Warning badge + short message; recording and transcript remain usable |
| `pending_config` | Neutral info: “Integrity hash recorded; timestamp service not configured” |
| (no record yet) | Subtle “Sealing pending…” while job runs |

When sealing is disabled for the user, show nothing (no empty states).

Copy guidelines (see [user-friendly-naming.md](../language/user-friendly-naming.md)):

- Prefer **integrity proof**, **tamper-evident archive**, **trusted timestamp**.
- Avoid **notarized**, **legally binding**, **medical record**, **patient**.

### 10.2 Admin user detail

Add a toggle in `/admin/users/:id`:

- Label: “Tamper-evident audio archiving”
- Help text: “When enabled, new recordings for this user receive an external trusted timestamp for the original audio file.”
- Audit action: `update_integrity_sealing` with before/after in `AdminAuditEvent`.

---

## 11. Failure modes and resilience

| Scenario | Behavior |
|---|---|
| TSA unreachable | `tsa_status: failed`, hash retained, session processing unaffected |
| TSA misconfigured (empty URL) | `pending_config`, hash retained |
| Job runs before blob fully uploaded | Job no-ops or retries via Active Job; do not mark session failed |
| User flag turned off after enqueue | Job checks flag at runtime and exits early |
| `original_audio` replaced | Existing integrity record may show `integrity_hash_matches_exported_file: false` on next download; document as stale proof |
| Sealing raises unexpectedly | Log warning; do not re-raise into transcription job |

---

## 12. Privacy and security

- **Data minimization:** The TSA receives only a SHA-256 digest (32 bytes). Audio content is never sent.
- **Re-identification risk:** Anyone holding the audio file can confirm it matches the hash. This is required for verification and should be noted in privacy documentation when the feature ships.
- **Storage:** `tsa_proof_blob` is not secret but should be protected by the same access controls as the recording (workspace tenancy, authentication).
- **No new third-party content processing:** Timestamping is metadata-only; transcription vendors are unchanged.
- **Test environment:** Default empty TSA URL prevents accidental external calls in CI.

---

## 13. Testing strategy

### 13.1 Unit tests

- DER request builder produces parseable structure (golden-byte or structural checks).
- TSA client: mock HTTP — success, network error, bad PKIStatus, missing token.
- `pending_config` when URL blank; hash still computed.
- `RecordingIntegrityService.upsert!` creates and updates records.

### 13.2 Integration tests

- Upload recording with sealing enabled → integrity record with `sealed` (mock TSA).
- Upload with sealing disabled → no integrity record.
- Processing completes with `status: completed` even when mock TSA returns failure.
- JSON certificate download includes `integrity_hash_matches_exported_file: true` for unchanged blob.

### 13.3 System tests (optional, env-guarded)

- End-to-end against a real TSA in staging only (`INTEGRITY_TSA_URL` set); not in default CI.

Follow [testing-guidelines.md](../testing/testing-guidelines.md): prefer fast integration tests over flaky browser tests.

---

## 14. Phasing

### Phase 1 (MVP)

- Migration: `recording_integrity_records`, `users.integrity_sealing_enabled`
- `lib/nodl/integrity/*` + `SealRecordingIntegrityJob`
- Admin toggle + audit
- Session page status + JSON certificate download
- Unit + integration tests with mocked TSA

### Phase 2 (hardening)

- Qualified EU TSA provider configuration for production
- Rake task / admin action: “Verify integrity proof” with full OpenSSL chain validation
- Metrics: `nodl.integrity.sealed`, `.failed`, latency histogram
- User-facing guide page for manual verification

### Phase 3 (optional)

- Include integrity sidecars in account data export ZIP
- Re-seal workflow if blob is intentionally replaced
- Anchor daily Merkle root of all hashes for scale (only if TSA cost becomes an issue)

---

## 15. Open questions

- **User vs workspace flag:** User story says per user; if a user joins multiple workspaces later, confirm sealing follows the creator, not the workspace.
- **Production TSA vendor:** FreeTSA for dev/staging; which qualified TSA for EU production (cost, SLA, eIDAS tier)?
- **Retry job for `failed`:** Automatic nightly retry vs manual admin “Re-seal” button?
- **Display timestamp source:** Prefer parsed token time vs HTTP `Date` when they diverge?
- **Legal copy review:** Final disclaimer text for certificate JSON and UI before public launch.

---

## 16. Handoff checklist

- [ ] User story acceptance criteria fully captured in phase 1 scope
- [ ] Migrations reviewed with `strong_migrations`
- [ ] Env vars documented in `README.md` (no secrets committed)
- [ ] Admin audit event for toggle changes
- [ ] i18n keys for EN + DE (neutral wording)
- [ ] `make check` green including new tests
- [ ] Privacy note drafted for release (hash sent to external TSA)
