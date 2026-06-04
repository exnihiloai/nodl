# Live Transcription — Design Document

> Status: **Approved** · Date: 2026-06-04 · Type: design-input
>
> This document describes *how the improved speech-to-text system should work*. It is the
> design contract. The companion [implementation-plan.md](implementation-plan.md) describes a
> *suggested* path to build it.

## 1. Summary

Today the app transcribes audio **only after recording finishes**: the browser records the whole
clip, uploads it, and a background job sends the full file to Gemini for transcription, then
document transformation (see [audio-pipeline.md](../../design-output/modules/audio-pipeline.md)).

This design adds **live transcription during recording** while keeping that final batch step as the
source of truth. It uses a **two-track hybrid**:

- **Live preview track** — short, self-contained audio *segments* cut at natural pauses are
  transcribed by Gemini as the user speaks and streamed to the page. This text is **throwaway**:
  fast, "good enough", never saved as the final result.
- **Authoritative track** — when recording stops, the **whole, uninterrupted clip** is transcribed
  in one Gemini pass (essentially today's pipeline). This produces the clean transcript **and** the
  stable speaker attribution (Person 1 / Person 2 / Person 3), and replaces the preview.

Uploaded audio files skip the live track entirely and go straight to the authoritative track.

## 2. Goals

- Live, near-real-time transcript shown **while** the user records from the microphone.
- Keep using the **Gemini API** for both transcription and document transformation (one vendor).
- Keep **offline transcription** for uploaded audio files, unchanged in spirit.
- **Speaker diarization**: when a recording (live or uploaded) has multiple speakers, attribute each
  utterance to a distinct speaker (Person 1, Person 2, Person 3, …).
- Cost-efficient and "good enough", not perfect.

## 3. Non-goals

- Sub-second, word-by-word streaming latency. A few seconds of lag in the *preview* is acceptable.
- Live, persisted speaker labels on the *preview* feed. Labels are finalized by the batch pass.
- Replacing Gemini with a dedicated ASR provider, or adding a second vendor (Groq/OpenAI/Deepgram).
- Real-time translation, voice commands, or edit-by-voice (freeflow features we are not copying).
- Speaker *identification* (matching to named people). We only do speaker *separation* + numbering.

## 4. Locked design decisions

These were decided during planning and frame everything below.

| # | Decision | Rationale |
|---|---|---|
| D1 | **Hybrid**: throwaway live preview + authoritative whole-file batch pass. | Live streaming and reliable diarization pull in opposite directions; the batch pass gives quality, the preview gives responsiveness. |
| D2 | **Speaker labels are finalized by the batch pass**, not on the live feed. | Diarization needs the *whole* recording to keep speaker identities stable. |
| D3 | **Live engine = segmented HTTP → Gemini** (Option 1). | No new infrastructure, one vendor, reuses `GeminiClient` + Turbo Streams, degrades gracefully. Sub-second latency was explicitly not required. |
| D4 | **Segments are cut at silence (VAD), not on a fixed clock.** | Fixed-interval cuts slice mid-word and cause hallucinated text ("Piccadilly" → "pick a silly"). Cutting in pauses keeps each segment a complete phrase. |
| D5 | **Final transcript quality is decoupled from the live engine.** | The preview is overwritten; preview errors never reach the saved document. |

Why not the alternatives (for the record): a true WebSocket streaming engine (Gemini Live API, or
freeflow-style Groq/OpenAI realtime) buys <1s latency at the cost of a Rails WebSocket proxy,
raw-PCM capture in the browser, socket-reliability work, and (for Groq) a second vendor. None of
that is justified when low latency is not a requirement and final quality comes from the batch pass.

## 5. Why segmentation does not hurt final quality

This is the crux of the design and worth stating explicitly.

A naive "cut every N seconds" approach **would** hurt quality, because a hard cut can land in the
middle of a word and the model will invent a plausible-but-wrong word on each side of the seam.

Two things neutralize this:

1. **The final transcript is a separate whole-file pass.** The authoritative Gemini call sees the
   entire, uninterrupted recording with full context, so it transcribes "Piccadilly Circus"
   correctly. Segment errors only ever appear in the *preview*, which is discarded on stop.

2. **Segments are cut at silence, not on a clock (D4).** Voice-activity detection closes a segment
   only after a short pause (≈300–500 ms below a loudness threshold), so boundaries land between
   words/phrases. The browser already computes microphone RMS loudness for the recording
   visualizer ([audio_recorder_controller.js](../../../app/javascript/controllers/audio_recorder_controller.js),
   `renderAura`); the same signal drives segmentation.

Net effect: the worst case is a brief, self-correcting wobble in the *preview*; the saved document
is never at risk.

## 6. System overview

### 6.1 Two tracks, one recording

```text
                            ┌───────────────────────── browser ─────────────────────────┐
  microphone ─▶ MediaStream ─┬─▶ Recorder A (continuous)  ──────────▶ full clip (on stop)
                             │
                             └─▶ Recorder B (segmenter) ──▶ segment 1 ─┐
                                  cuts at silence (VAD)    ──▶ segment 2 ─┤ POST per segment
                                                            ──▶ segment N ─┘
                            └────────────────────────────────────────────────────────────┘
                                          │  segments                      │  full clip
                                          ▼                                ▼
   LIVE PREVIEW TRACK            POST /…/segments              FINALIZE (on stop)
   (throwaway)                          │                            │
                              TranscribeSegmentJob          ProcessRecordingSessionJob
                                  Gemini (per segment)         Gemini (whole file, diarized)
                                          │                            │
                              Turbo Stream: append            Turbo Stream: replace preview
                              live preview text                with authoritative transcript
                                                                       │
                                                              document transformation
```

The microphone stream feeds **two recorders**:

- **Recorder A — continuous.** One uninterrupted recording of the whole clip. This is today's
  recorder, essentially unchanged. On stop it produces the file that feeds the authoritative pass.
  Keeping it continuous guarantees the authoritative audio has **no seams or gaps**.
- **Recorder B — segmenter.** Produces a sequence of short, **independently decodable** audio
  segments, each cut at a silence boundary. Each finished segment is POSTed for live transcription.

Running two `MediaRecorder`s on one `MediaStream` is supported and keeps the authoritative audio
pristine while still yielding clean segments for preview. (An alternative single-recorder approach
is noted in §11.)

### 6.2 Live preview lifecycle

1. User presses **Record**. A `RecordingSession` is created immediately with status `recording`,
   so it has an id and a Turbo Stream channel before any audio is uploaded.
2. Recorder B emits segment *k* at a pause. The browser POSTs it to the session's segment endpoint
   with a monotonically increasing index.
3. The endpoint stores the segment briefly and enqueues a job; it returns immediately (the POST
   never waits on Gemini).
4. The job transcribes the segment with the cheap Gemini model and broadcasts the text to the
   session's Turbo Stream. The preview view renders segments **ordered by index** (jobs may finish
   out of order).
5. The user sees the transcript grow, a few seconds behind their speech.

### 6.3 Finalization (authoritative pass)

1. User presses **Stop**. Recorder A's continuous clip is uploaded to a finalize action.
2. The session moves `recording → processing`; `ProcessRecordingSessionJob` runs the existing
   pipeline: normalize → whole-file Gemini transcription (now with a refined diarization prompt) →
   document transformation.
3. On completion the session moves to `completed`; the authoritative transcript **replaces** the
   live preview, and the generated document is linked in the dashboard activity feed (unchanged).
4. Throwaway live segments for the session may be discarded.

### 6.4 Upload path (unchanged)

Uploading a file creates a session **with the file already attached** and goes straight to
`ProcessRecordingSessionJob`. There is no live track. This path is identical to today except it
benefits from the improved diarization prompt.

## 7. Segmentation strategy (browser, Recorder B)

- **Silence-gated cuts (primary).** Track short-window RMS loudness (reuse the visualizer's
  analyser). While loudness is above a threshold, keep the current segment open. When loudness stays
  below the threshold for a hangover window (≈300–500 ms), close the current segment and start the
  next. Boundaries land in pauses.
- **Max-length safety valve.** If the user talks continuously past a cap (≈20–25 s) with no qualifying
  pause, force a cut so the preview does not fall too far behind. An occasional mid-phrase cut is
  acceptable for a preview.
- **Minimum-length floor.** Ignore ultra-short blips (e.g. < 1 s of speech) to avoid spamming the API
  with noise-only segments.
- **Optional seam overlap.** Optionally prepend the last ≈0.5 s of the previous segment to the next
  to give the model run-up context. Default off; enable if seams look rough.
- **Format.** Segments use the same `MediaRecorder` MIME negotiation as today
  (`audio/webm;codecs=opus` etc.). Each segment is a complete file (the segmenter stops/restarts, so
  every segment carries its own container header and is independently decodable).

Tuning knobs (threshold, hangover, max-length, min-length, overlap) should be constants that are
easy to adjust after real-world listening; they do not affect final quality.

## 8. Speaker diarization

### 8.1 Where it happens

Diarization is produced **only by the authoritative whole-file pass** (D2). The live preview shows
plain text without trying to attribute speakers.

### 8.2 Output shape

The transcription prompt is refined to emit **stable, numbered speaker labels** when more than one
speaker is present, e.g.:

```text
Speaker 1: I went to Piccadilly Circus in the afternoon.
Speaker 2: Did you pick up your daughter on the way?
Speaker 1: Yes, right after.
```

Requirements for the prompt/output:

- Single-speaker recordings produce **no** speaker labels (avoid noise for the common case).
- Multi-speaker recordings number speakers consistently across the whole transcript (Speaker 1 stays
  Speaker 1 from start to end).
- Labels are generic and ordinal (Speaker 1/2/3), not guessed names.
- The transcript remains plain, readable text (Markdown-friendly) — the document transformation step
  consumes it as today.

### 8.3 Storage

`recording_sessions.transcript_text` remains the canonical transcript and now carries the labeled
text. Parsing speaker turns into a **structured** form (per-utterance speaker + text records) is a
possible later enhancement for richer UI (e.g. colored speaker bubbles); it is **out of scope** for
this design, which keeps the transcript as labeled text.

## 9. Data model & state

### 9.1 Session status

Add a `recording` state so a session can exist while audio is still being captured:

```text
recording  → session created on Record press; live segments stream in
processing → Stop pressed; authoritative pass running (existing)
completed  → authoritative transcript + document ready (existing)
failed     → error (existing)
```

`pending` remains valid for the upload path (file attached, not yet picked up).

### 9.2 Live segments

Live segments are **ephemeral working data**, not part of the saved result. Persisting them as
lightweight records (index, status, transcribed text, optional blob) buys: stable ordering, refresh
resilience, and debuggability — at the cost of a small table and cleanup on finalize. The
implementation plan treats this as the recommended-but-optional approach and offers a
cache/in-memory alternative.

## 10. Failure modes & graceful degradation

- **A segment fails to transcribe.** The preview shows a small gap for that segment; the authoritative
  pass is unaffected. Do not fail the session.
- **The whole live track fails** (network, Gemini hiccup, browser quirk). Recording continues; the
  user simply gets less/no live feedback. On stop, the authoritative pass still runs normally.
- **Browser cannot run two recorders / segment.** Fall back to today's behavior: continuous recording
  only, no live preview, authoritative pass on stop. Live transcription is an enhancement, never a
  prerequisite for getting a document.
- **Authoritative pass fails.** Existing behavior: session marked `failed` with a message.
- **User closes the tab mid-recording.** The `recording` session is abandoned; a periodic cleanup
  reaps stale `recording` sessions with no finalized audio.

## 11. Alternatives considered (and why not)

- **True WebSocket streaming (Gemini Live API or Groq/OpenAI realtime).** Lower latency, but requires
  a Rails WebSocket proxy, raw-PCM capture, backpressure/reconnect handling, and (Groq) a second
  vendor. Rejected per D3 — latency is not a requirement.
- **Single continuous recorder + server-side segment concatenation.** Avoids a second browser
  recorder, but reconstructing decodable segments from `MediaRecorder` chunks is fragile (only the
  first chunk has the container header) and concatenation can introduce seams in the authoritative
  audio. The two-recorder approach (§6.1) is simpler and safer; server concat is a possible later
  optimization if double-recording proves costly on low-end devices.
- **Persisting live preview as the final transcript** (skip the batch pass). Rejected — it sacrifices
  diarization quality and re-introduces the seam problem (§5).
- **Fixed-interval segmentation.** Rejected per D4 (mid-word cuts).

## 12. Cost & privacy notes

- **Cost shape:** authoritative pass (≈ audio length, as today) **plus** live segments (≈ audio length
  again, spread across many small calls). Use the cheap Gemini flash-lite model for segments; coarser
  segments reduce call count. Treat the live track as an optional, possibly toggleable, cost.
- **Privacy:** audio still leaves only to Gemini, same as today. Live segments are transient and should
  be deleted after finalization. No new vendor or data path is introduced.

## 13. Open questions

- Default segment length / silence thresholds — pick initial values, then tune against real German and
  multi-speaker recordings.
- Whether to expose a **"live preview on/off"** toggle (cost control / privacy).
- Whether to later parse speaker turns into structured records for a richer multi-speaker UI.
- Whether uploaded files should ever get a (post-hoc, non-live) speaker-segmented preview — currently
  no; they go straight to the authoritative transcript.
