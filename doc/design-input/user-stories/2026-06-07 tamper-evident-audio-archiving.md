# User Story: Tamper-Evident Audio Archiving

> **Implementation order: ship second**, after [2026-06-07 obtain-original-audio.md](2026-06-07%20obtain-original-audio.md).  
> Design: [../domain/tamper-evident-audio-archiving.md](../domain/tamper-evident-audio-archiving.md)

As a logged-in user who records important conversations in Nodl,
I want each recording to include verifiable proof that it existed at a specific time and has not been altered since,
so that I can demonstrate authenticity and integrity if the recording is ever questioned.

## Prerequisites

- **Obtain Original Audio Recording** is implemented: users can download the original audio file from a recording session. This story adds sealing and a packaged proof download; it does not introduce original-audio delivery from scratch.

## Acceptance Criteria

### Enablement
- The feature can be turned on or off per user; default is **off**.
- Only an administrator can change this setting; ordinary users cannot toggle it.

### Sealing
- When enabled, each new recording session with original audio receives an integrity proof for the **original** file (not the normalized playback version).
- The proof includes a SHA-256 fingerprint and an externally signed trusted timestamp.
- Only a hash is sent externally for timestamping; the audio content stays in Nodl.
- Transcription and document generation still succeed if timestamping fails; sealing must not block the main workflow.

### User visibility and download
- When the feature is on for the user, the recording session page shows whether integrity sealing succeeded, is pending, or failed.
- When a proof exists (`sealed`), the user can download a **ZIP archive** that contains:
  - the **original audio file** (same bytes as the standalone download from the prerequisite story), and
  - an **integrity certificate** (JSON sidecar) with hash, timestamp, proof blob, and whether the bundled audio still matches the stored hash.
- The plain “Download original audio” action from the prerequisite story remains available; the ZIP is the packaged proof export for verification and dispute scenarios.
- When the feature is off for the user, no integrity UI or ZIP download is shown.

## Out of Scope

- Legal notarization or guaranteed admissibility in court.
- Sealing transcripts, documents, or normalized audio.
- User-facing toggle; workspace-level default for all members.
- Retroactive sealing of recordings created before the feature was enabled (phase 1).
- Standalone JSON certificate download without the audio file in the same archive.

## Edge Cases

- Timestamp service unavailable → session and transcript remain usable; failure is visible on the session; plain audio download still works.
- Sealing still pending → show pending state; ZIP download only when proof is `sealed`.
- Bundled audio no longer matches stored hash → certificate reflects mismatch; do not silently claim validity.
