# User Story: Obtain Original Audio Recording

> **Implementation order: ship first.** Standalone feature; no dependency on tamper-evident archiving.  
> Follow-up: [2026-06-07 tamper-evident-audio-archiving.md](2026-06-07%20tamper-evident-audio-archiving.md) builds on this later.

As a logged-in user,
I want to download the original audio file for a recording session in my workspace,
so that I can keep a copy outside Nodl, share it when needed, or use it in other tools.

## Acceptance Criteria

### Availability
- A download action is available on the recording session page when the session has an attached original audio file and is no longer recording or processing.
- The downloaded file is the **original** upload or microphone capture — not the normalized file used for in-app playback when conversion occurred.
- Users can only download recordings from their current workspace.
- Admins cannot download originals for users they manage; only the session owner’s workspace access applies.

### Download behavior
- The browser receives a **single audio file** (not a ZIP in this story).
- Filename is sensible: preserve the original filename when known; otherwise derive one from session title, date/time, and detected format.
- Response uses the correct content type for the stored original file.
- Works for all supported original formats (e.g. WebM, MP3, WAV, M4A).

### UX
- Control is easy to find on the recording session page (e.g. near the audio player or session header), labeled clearly as “Download original audio”.
- While recording or processing, the action is hidden or disabled with an explanatory state — not an error.

## Out of Scope

- Integrity proofs, trusted timestamps, or certificate downloads.
- ZIP archives bundling audio with metadata (see tamper-evident story).
- Downloading the normalized playback file instead of the original.
- Bulk export of all recordings; unauthenticated or cross-tenant links.
- Re-encoding, trimming, or watermarking on download.

## Edge Cases

- Original audio missing or unreadable in storage → clear error; no broken download.
- Large files (within existing size limits) download reliably under normal conditions.
- Unsafe characters in the original filename → sanitize for the download filename only.

## Additional Information

- Download is available for `failed` sessions when original audio was attached and the file still exists.
