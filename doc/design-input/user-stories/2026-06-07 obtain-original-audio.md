# User Story: Obtain Original Audio Recording

> Related: [2026-06-07 tamper-evident-audio-archiving.md](2026-06-07%20tamper-evident-audio-archiving.md) (integrity proofs apply to the downloaded original file)

As a logged-in user,
I want to download the original audio file for a recording session I own in my workspace,
so that I can keep a copy outside Nodl, share it when needed, and verify an integrity proof against the exact file that was captured.

## Acceptance Criteria

### Availability
- A download action is available on the recording session page when the session has an attached original audio file.
- The downloaded file is the **original** upload or microphone capture — not the normalized file used for in-app playback when conversion occurred.
- Users can only download recordings from their current workspace.
- Admins cannot download originals for users they manage. Only the user has access to their own data.

### Download behavior
- The browser receives the file with a sensible filename (preserve the original filename when known; otherwise derive one from the session title, date and time, and detected format).
- The response uses the correct content type for the stored original file.
- Download works for all supported original audio formats already accepted on upload/recording (e.g. WebM, MP3, WAV, M4A).

### UX
- The download control is easy to find on the recording session page (e.g. near the audio player or session header), with clear labeling such as “Download original audio”.
- While a session is still recording or processing, the download action is hidden or disabled with an explanatory state — not an error.

### Integrity alignment
- When tamper-evident archiving is enabled for the user, the file returned by this download is the same bytes used for the integrity hash and trusted timestamp (when sealing succeeded or hash was recorded).

## Out of Scope

- Downloading the normalized playback file instead of (or separately from) the original.
- Bulk export of all recordings in one archive (account-wide data export).
- Download by unauthenticated or cross-tenant links.
- Re-encoding, trimming, or watermarking the file on download.

## Edge Cases

- Session completed but original audio missing or corrupted in storage → show a clear error; do not offer a broken download.
- Very large files (up to the existing recording size limit) download without timing out under normal conditions.
- Original filename contains unsafe characters → sanitize for the downloaded filename without changing stored blob content.

## Additional Information

- Download should be available for `failed` sessions if original audio was attached before failure and if the file exists.

