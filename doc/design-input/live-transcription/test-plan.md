# Live Transcription — Test Plan

> Status: **Proposed** · Date: 2026-06-04 · Type: design-input
>
> A lean test plan for the feature in [design.md](design.md) /
> [implementation-plan.md](implementation-plan.md). Goal (per
> [testing-guidelines.md](../../design-input/testing/testing-guidelines.md)): a **small, meaningful**
> suite that proves the happy paths and prevents the obvious failures — not maximum coverage.

## Principles

- **Behavior over implementation.** Test user outcomes, state transitions, authorization, and graceful
  degradation — not VAD constants, private methods, or layout.
- **Gemini and ffmpeg are always stubbed.** No network or real conversion in CI/local. A manual private
  smoke test may exist but is never required.
- **Live is an enhancement.** Every failure-mode test must confirm the user still gets a final transcript
  and document when the live track breaks.
- **Extend existing files** where natural (see references below) rather than inventing parallel suites.

## Existing files to extend

```text
test/models/recording_session_test.rb              # +recording state, conditional audio validation
test/integration/recording_sessions_integration_test.rb  # +create-in-recording, finalize, segments
test/jobs/process_recording_session_job_test.rb     # unchanged authoritative path stays green
test/services/recording_session_processor_test.rb   # diarized transcript persisted
test/lib/nodl/gemini_transcriber_test.rb            # +diarization prompt shape
test/system/dashboard_tenancy_test.rb / dashboard smoke  # +live pane hooks
```

Likely new: `test/jobs/transcribe_segment_job_test.rb`, `test/models/recording_segment_test.rb` (if the
segment table is used).

---

## Happy paths (must pass)

### HP-1 — Diarization prompt (Phase 0, unit)
- The transcription prompt asks for stable, numbered speaker labels and plain-text output.
- *File:* `test/lib/nodl/gemini_transcriber_test.rb`.

### HP-2 — Multi-speaker upload is attributed (service/job)
- A stubbed multi-speaker Gemini response is persisted to `transcript_text` with `Speaker 1/2/3` labels,
  and the document is generated from it.
- A single-speaker stubbed response persists **without** speaker labels.
- *File:* `test/services/recording_session_processor_test.rb`.

### HP-3 — Mic flow: create → finalize (integration)
- `POST` create in `recording` state succeeds with no audio attached and returns the session id.
- `finalize` attaches the continuous clip, moves `recording → processing`, and enqueues
  `ProcessRecordingSessionJob`.
- *File:* `test/integration/recording_sessions_integration_test.rb`.

### HP-4 — Upload flow unchanged (integration)
- Uploading a file still creates a session with audio attached and enqueues processing (regression guard
  for the existing path).
- *File:* `test/integration/recording_sessions_integration_test.rb`.

### HP-5 — Segment ingestion + transcription (integration + job)
- `POST /recording_sessions/:id/segments` with a blob + index returns immediately (no Gemini call inline)
  and enqueues `TranscribeSegmentJob`.
- `TranscribeSegmentJob` with a stubbed Gemini response stores the segment text and broadcasts to the
  session's live stream.
- *Files:* integration test + `test/jobs/transcribe_segment_job_test.rb`.

### HP-6 — Ordered live preview (job/model)
- Segments completing **out of order** (index 2 before index 1) still render ordered by index.
- *File:* segment/job test (and/or a view-render assertion).

### HP-7 — Live pane present while recording (smoke/system)
- A `recording` session exposes a stable live-transcript hook (`data-testid`) subscribed to the live
  stream; a `completed` session shows the authoritative transcript instead.
- *File:* dashboard smoke / `rack_test` system test. Browser-driven JS coverage stays behind
  `JS_SYSTEM_TESTS=1` and small.

---

## Failure modes (must be prevented)

### FM-1 — One segment fails → session unaffected
- `TranscribeSegmentJob` with a Gemini error marks **only that segment** failed (or no-ops), does **not**
  raise into the session, and leaves the session usable.
- *File:* `test/jobs/transcribe_segment_job_test.rb`.

### FM-2 — Live track absent → final result still produced
- A finalize with **no segments ever posted** still produces the authoritative transcript + document.
- *File:* integration test.

### FM-3 — Segment endpoint is state- and tenant-guarded
- Posting a segment to a session **not** in `recording` state is rejected.
- Posting a segment to **another workspace's** session is forbidden (tenant boundary).
- Endpoint requires authentication and CSRF protection like the rest of the controller.
- *File:* integration test.

### FM-4 — Authoritative pass failure marks session failed
- A Gemini failure in `ProcessRecordingSessionJob` marks the session `failed` with a useful message
  (existing behavior; keep green).
- *File:* `test/jobs/process_recording_session_job_test.rb`.

### FM-5 — Conditional audio validation
- A `recording` session is valid **without** audio; a finalize/upload session is **invalid** without
  audio (the old "audio required" rule still holds where it should).
- *File:* `test/models/recording_session_test.rb`.

### FM-6 — Abandoned recording sessions don't linger
- A `recording` session never finalized is reapable (assert the cleanup scope/criteria, not timing).
- *File:* `test/models/recording_session_test.rb` (scope) — only if the reaper is implemented.

---

## Coverage matrix

| ID | Layer | Phase |
|---|---|---|
| HP-1 | unit (lib) | 0 |
| HP-2 | service | 0 |
| HP-3 | integration | 1 |
| HP-4 | integration | 1 (regression) |
| HP-5 | integration + job | 2 |
| HP-6 | job/view | 2 |
| HP-7 | smoke/system | 4 |
| FM-1 | job | 2 |
| FM-2 | integration | 1–2 |
| FM-3 | integration | 2 |
| FM-4 | job | (existing) |
| FM-5 | model | 1 |
| FM-6 | model | 5 |

## Out of scope for this plan

- VAD tuning constants, exact segment timing, animation/visualizer details.
- Real Gemini quality / diarization accuracy (validate via the manual private smoke test, not CI).
- Structured per-utterance speaker records (deferred feature).

## Gate

```sh
make test     # bin/rails test + bin/rails test:system, Gemini/ffmpeg stubbed
make lint
# JS recording behavior, when touched:
JS_SYSTEM_TESTS=1 docker compose exec web bin/rails test test/system/audio_recorder_js_test.rb
```
