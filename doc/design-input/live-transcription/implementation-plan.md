# Live Transcription — Implementation Plan

> Status: **Approved** · Date: 2026-06-04 · Type: design-input
>
> This is a **suggested** path and a set of guidelines for building the system described in
> [design.md](design.md). It is **not a hard rule**. Phase boundaries, file names, and table shapes
> are starting points — adapt them as the code reveals better options. Each phase is independently
> shippable and leaves the app working.

## Guiding principles

- **The authoritative path barely changes.** Most of today's pipeline
  ([recording_session_processor.rb](../../../app/services/recording_session_processor.rb),
  [pipeline.rb](../../../lib/nodl/pipeline.rb),
  [gemini_transcriber.rb](../../../lib/nodl/transcription/gemini_transcriber.rb)) is reused as-is. The
  bulk of new code is the **live preview track**.
- **Live is an enhancement, never a prerequisite.** If anything in the live track breaks, the user
  must still get a document from the authoritative pass.
- **Follow existing conventions:** thin controllers, logic in services/jobs, Active Job for slow work,
  Turbo Streams for live UI, Stimulus for browser behavior, Minitest with mocked Gemini.
- **Ship behind a flag** if convenient, so the live track can be disabled in production while iterating.

## Phase map

| Phase | Outcome | Risk |
|---|---|---|
| 0 | Diarization prompt refinement (authoritative path only) | Low |
| 1 | Session can exist in `recording` state; finalize flow | Low–med |
| 2 | Backend segment ingestion + live transcript broadcast | Medium |
| 3 | Browser: two-recorder capture + VAD segmentation | Medium–high |
| 4 | UI: live preview pane → authoritative replacement | Low–med |
| 5 | Cleanup, cost controls, tests, docs | Low |

Phases 0–1 deliver value (better diarization, finalize plumbing) even if the live track is never
finished. Phases 2–4 are the live preview. Phase 5 hardens.

---

## Phase 0 — Diarization prompt (authoritative path)

**Goal:** the whole-file pass emits stable, numbered speaker labels for multi-speaker audio, and none
for single-speaker audio. No live work yet.

- Refine `PROMPT` in
  [gemini_transcriber.rb](../../../lib/nodl/transcription/gemini_transcriber.rb) to:
  - use consistent ordinal labels (`Speaker 1:`, `Speaker 2:`, …) kept stable across the transcript,
  - emit labels **only** when more than one speaker is detected,
  - keep returning plain transcript text (no JSON), so the transformer step is unaffected.
- Sanity-check that the document transformation prompt and templates read naturally with speaker
  labels present.

**Tests:** unit test asserting prompt content/shape; existing transcriber tests still green (Gemini
mocked). Optionally a private live smoke test with a real multi-speaker clip (not in CI).

**Done when:** a multi-speaker upload produces a transcript with clean Speaker N attribution and a
single-speaker upload has none.

---

## Phase 1 — `recording` state + finalize flow

**Goal:** a session can be created at **Record** press and finalized at **Stop**, without breaking the
existing upload-creates-session-with-file flow.

- **Status enum:** add `recording` to `RecordingSession`
  ([recording_session.rb](../../../app/models/recording_session.rb)) and to the
  `recording_sessions.status` column usage. Keep `pending` for uploads.
- **Validation:** `original_audio` is required for upload/finalize but **not** at the moment a
  `recording` session is first created (no audio yet). Make the attachment validation conditional on
  state so a live session can start audio-less.
- **Routes/actions:** allow creating a session in `recording` state (mic flow) and a **finalize**
  action that attaches the continuous clip and enqueues `ProcessRecordingSessionJob`. Options:
  - add `:update`/`finalize` to `resources :recording_sessions`, or
  - a nested member route (`POST /recording_sessions/:id/finalize`).
  Keep the controller thin; push any logic to a service if it grows.
- **Job trigger:** finalize sets `processing` and enqueues the existing job — the authoritative path is
  otherwise unchanged.

**Tests:** request specs for create-in-recording, finalize-attaches-and-enqueues, and the unchanged
upload path; model tests for the conditional audio validation.

**Done when:** mic flow = create (`recording`) → finalize (`processing` → `completed`); upload flow
unchanged.

---

## Phase 2 — Backend segment ingestion + live broadcast

**Goal:** accept live audio segments for a `recording` session, transcribe each asynchronously, and
broadcast ordered preview text over Turbo Streams.

- **Endpoint:** `POST /recording_sessions/:id/segments` accepting an audio blob + integer `index`.
  Authorize against the current workspace exactly like the existing controller. Validate the session is
  in `recording` state. **Return immediately** — never block on Gemini.
- **Storage (recommended):** a lightweight `recording_segments` table:
  `recording_session_id`, `index`, `status` (pending/completed/failed), `text`, timestamps; optionally
  the audio via Active Storage. Unique index on `(recording_session_id, index)` for ordering and
  idempotent retries.
  - *Alternative:* skip the table and keep an ordered buffer in Solid Cache keyed by session id. Less
    debuggable, no migration. Either is fine — the table is the more Rails-idiomatic choice.
- **Job:** `TranscribeSegmentJob` transcribes one segment with the cheap Gemini model via the existing
  `GeminiTranscriber`/`GeminiClient`, stores the text, and broadcasts.
  - Reuse `Nodl::Transcription::GeminiTranscriber` with a **plain (non-diarized)** prompt for segments,
    or pass a prompt variant — segments are single-phrase previews and should stay simple/cheap.
  - On failure: mark the segment `failed`, broadcast nothing (or a subtle gap marker), **do not** fail
    the session.
- **Broadcast:** append/replace into a `live_transcript` target on the session's Turbo Stream
  (`[workspace, :dashboard]` already exists; consider a per-session stream
  `[recording_session, :live]` to avoid noise). Render segments **ordered by index** so out-of-order
  job completion still reads correctly.

**Tests:** request spec for the segment endpoint (auth, state guard, enqueues job, fast return); job
test with mocked Gemini (success + failure → graceful); broadcast/ordering test.

**Done when:** POSTing segments to a `recording` session produces ordered live text via Turbo, and a
failing segment leaves a gap without breaking anything.

---

## Phase 3 — Browser capture + VAD segmentation

**Goal:** the recorder produces both a continuous clip (authoritative) and silence-cut segments
(preview), reusing the existing loudness signal.

Work in [audio_recorder_controller.js](../../../app/javascript/controllers/audio_recorder_controller.js):

- **On Record:** create the session (Phase 1) to get its id, then start:
  - **Recorder A (continuous):** today's `MediaRecorder`, one uninterrupted recording → uploaded on
    Stop to the finalize action.
  - **Recorder B (segmenter):** a second `MediaRecorder` on the **same** `MediaStream`, stopped and
    restarted at silence boundaries so each segment is a complete file.
- **VAD:** reuse the analyser RMS already computed in `renderAura`. Maintain segmenter state: open a
  segment on speech onset; after a hangover of low loudness (≈300–500 ms), stop Recorder B (flush the
  segment) and start a fresh one. Enforce a max-length safety valve (≈20–25 s) and a min-length floor
  (≈1 s). Expose threshold/hangover/min/max/overlap as tunable constants.
- **Upload segments:** on each Recorder B `stop`, POST the blob + incrementing index to the Phase 2
  endpoint (fire-and-forget; ignore individual failures).
- **On Stop:** stop both recorders, upload Recorder A's clip to finalize.
- **Capability fallback:** if a second recorder or the analyser is unavailable, run Recorder A only and
  skip the live track (today's behavior).
- **Upload-file path:** unchanged — `useUpload` still goes straight to create-with-file.

**Tests:** prefer request/integration coverage for the backend; keep browser-only system tests light
and behind the existing JS system-test flag. A system test can assert the live pane updates during a
simulated recording if it is stable; otherwise rely on the backend tests.

**Done when:** speaking shows live text a few seconds behind, segment boundaries land in pauses, and
the continuous clip still feeds a clean authoritative transcript.

---

## Phase 4 — UI: preview → authoritative replacement

**Goal:** a clear live pane during recording that is cleanly replaced by the authoritative transcript.

- Add a **live transcript pane** to the dashboard record hero
  ([dashboard/show.html.erb](../../../app/views/dashboard/show.html.erb)), shown while a session is
  `recording`, subscribed to the per-session live stream.
- Communicate honestly that the live text is a **preview that will be cleaned up** — the design accepts
  occasional self-correcting wobble. Consider a subtle "finalizing…" state during `processing`.
- On `completed`, replace the preview with the authoritative, speaker-labeled transcript and surface
  the generated document via the existing activity feed.
- Keep DaisyUI components and existing copy/voice. No SPA patterns.

**Tests:** view/partial render tests for the live pane and the recording/processing/completed states.

**Done when:** the record experience reads as: live preview → "finalizing" → clean diarized transcript
+ document.

---

## Phase 5 — Hardening: cleanup, cost, tests, docs

- **Cleanup:** delete live segments (rows/blobs/cache) on finalize. Add a periodic reaper for stale
  `recording` sessions abandoned by closed tabs.
- **Cost controls:** confirm segments use the cheap model; consider a **live-preview on/off** flag
  (env or per-workspace) and coarser default segments to limit per-recording API calls.
- **Observability:** log/measure segment latency and failure rate (reuse existing telemetry if present).
- **Full test pass:** `make lint` and `make test` (`bin/rails test` + `bin/rails test:system`). Keep
  Gemini mocked in CI; no network.
- **Docs:** update
  [audio-pipeline.md](../../design-output/modules/audio-pipeline.md) and
  [dashboard.md](../../design-output/modules/dashboard.md) to describe the two-track flow once it
  lands, and move/flip this design from "Proposed" to reflect what shipped.

---

## Suggested new/changed files (orientation, not a contract)

```text
Changed:
  app/models/recording_session.rb                         # +recording status, conditional audio validation
  app/controllers/recording_sessions_controller.rb        # create-in-recording, finalize, segments (or split controller)
  app/javascript/controllers/audio_recorder_controller.js # two recorders + VAD segmentation
  app/views/dashboard/show.html.erb                        # live transcript pane
  lib/nodl/transcription/gemini_transcriber.rb            # refined diarization prompt (Phase 0)
  config/routes.rb                                         # finalize + segments routes
  db/migrate/* , db/schema.rb                              # recording_segments table (if persisted)

New (suggested):
  app/jobs/transcribe_segment_job.rb                      # async per-segment transcription
  app/models/recording_segment.rb                         # if persisting segments
  app/services/recording_finalizer.rb                     # optional, if finalize logic grows
  test/...                                                 # request/job/model/view coverage
```

## Risks & things to watch

- **Double API spend** from the live track — keep segments cheap/coarse and consider a toggle.
- **Two recorders on low-end devices** — watch CPU; the §11 server-concat alternative is the fallback.
- **Out-of-order segment jobs** — always render by index, never by arrival.
- **Seam wobble in preview** — acceptable by design; tune VAD or enable seam overlap if distracting.
- **Diarization consistency** — validate Speaker N stability on real 2–3 speaker clips before trusting it.

## Deferred (explicitly out of scope here)

- Structured per-utterance speaker records and a richer multi-speaker UI.
- True WebSocket streaming engines.
- Speaker *identification* (named people).
- Post-hoc speaker-segmented preview for uploaded files.
