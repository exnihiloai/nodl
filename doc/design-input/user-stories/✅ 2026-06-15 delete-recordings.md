# User Story: Delete Recordings

As a logged-in user who creates voice notes in Nodl,
I want to delete unwanted recordings from my dashboard,
so that I can keep my workspace tidy and free up recording quota.

## Acceptance Criteria

### Scope & permissions
- Delete for every session in dashboard **Recent** (`completed`, `failed`, `processing`, `pending`).
- Live-capture sessions (`recording`) are not listed and not deletable here.
- Any workspace member who can view the session may delete it (`current_workspace` scope).
- **Permanent** hard delete — no trash, undo, or restore.

### Desktop & tablet (≥ `sm`)
- Ellipsis **Actions** menu per row (same dropdown pattern as recording detail page).
- One item: **Delete** (trash icon, `text-error`).
- Opens app-wide confirm modal (`data-turbo-confirm`) naming the recording title; warns that audio, transcript, document, and integrity proof (if any) are permanently removed.
- **Sealed** integrity → stronger warning copy.
- Success: Turbo Stream row removal + notice. Failure: row stays + error notice.

### Mobile (< `sm`)
- Swipe left reveals red delete affordance with animated trash icon.
- Cancel by swiping back or releasing before the stop threshold.
- Threshold reached or tap on revealed control → same confirm modal (swipe alone does not delete).

### Data removed
`RecordingSession` hard delete including encrypted fields, `original_audio`/`normalized_audio` blobs, `document`, `recording_integrity_record`, and `work_path` artifacts. In-flight jobs become no-ops.

### Side effects
- Does not reduce append-only trial usage; quota behavior is owned by the entitlement policy.
- Open detail page → redirect to dashboard (“recording no longer exists”).
- Last item deleted → empty Recent state.
- Same Delete action on `recording_sessions#show` (phase 1).

## Out of Scope
Bulk delete, soft delete/undo, admin audit log, delete via push/email, legal hold.

## Edge Cases
- Delete while processing → job exits cleanly; no stuck progress UI.
- Failed and sealed sessions deletable (sealed: extra warning).
- Repeat delete → safe “already deleted” outcome.
