# Live Transcription & Audio Playback

> Type: design-output · Describes the **implemented** system as of 2026-06-05.
>
> This supersedes the historical Gemini segmented-HTTP proposal under
> [`design-input/live-transcription/`](../../design-input/live-transcription/design.md). The shipped
> system uses **Mistral Voxtral** for transcription (Gemini is used only for the
> transcript→document step). See also [audio-pipeline.md](audio-pipeline.md).

## Overview

A microphone recording has **two transcription tracks**, both powered by Mistral Voxtral:

1. **Realtime live preview** — while recording, the browser streams PCM audio through a Rails
   Action Cable proxy to Voxtral's realtime WebSocket and shows text as the user speaks. This text
   is throwaway.
2. **Authoritative batch pass** — on Stop, the continuous full clip is uploaded and transcribed in
   one Voxtral batch call (with diarization + segment timestamps). It replaces the preview and is the
   saved transcript that feeds document generation.

Uploaded files skip the live track and go straight to the batch pass.

Gemini is **not** used for transcription anymore — only for `transcript → Markdown document`.

## Realtime live preview

### Audio capture (browser)

[`audio_recorder_controller.js`](../../../app/javascript/controllers/audio_recorder_controller.js)
runs two things off one `getUserMedia` stream:

- A continuous `MediaRecorder` that captures the **authoritative full clip** (uploaded on Stop).
- An **AudioWorklet** ([`audio_pcm_worklet.js`](../../../app/assets/javascripts/audio_pcm_worklet.js))
  that downsamples the mic to **16 kHz mono `s16le` PCM**, emits ~40 ms frames (640 samples), and
  sends each frame base64-encoded over an Action Cable subscription.

If `AudioWorklet`/`AudioContext` is unavailable, the live track is skipped; recording and the final
transcript still work (graceful degradation).

### Server proxy (why a proxy is required)

Voxtral realtime authenticates with a **server-side API key only** — there is no browser token — so
the browser cannot talk to Mistral directly. Rails proxies the socket:

- [`LiveTranscriptionChannel`](../../../app/channels/live_transcription_channel.rb) (Action Cable)
  authenticates the user + workspace + a `recording`-state session, then opens **outbound** Voxtral
  realtime WebSockets and forwards base64 PCM frames to them. Text deltas are `transmit`ed back to
  the browser.
- [`MistralRealtimeClient`](../../../lib/nodl/providers/mistral_realtime_client.rb) wraps the
  outbound socket using the `async-websocket` gem (fiber-based, no EventMachine).

### Dual fast/slow streams → provisional + confirmed text

The channel opens **two** realtime streams with different `target_streaming_delay_ms`:

- **fast** (`NODL_VOXTRAL_REALTIME_FAST_DELAY_MS`, default 240 ms) → quick, low-confidence text.
- **slow** (`NODL_VOXTRAL_REALTIME_SLOW_DELAY_MS`, default 2400 ms) → refined, confident text.

The browser renders the **slow** stream as the confirmed prefix (normal/black) and the still-
unconfirmed tail of the **fast** stream as provisional (orange), split on word boundaries. As the
slow stream catches up, confirmation fills in left-to-right while the orange tail shrinks — it never
blanks out and re-fills. Realtime **cannot diarize**, so the preview is plain text; speakers come
only from the batch pass.

### Latency note (important)

`protocol-websocket` only flushes the outbound socket at the start of a `read`. The audio writer
therefore runs **inside the Async reactor as a fiber** and calls `@connection.flush` after **every**
frame. Without the per-frame flush, buffered audio only reached Mistral on the next read cycle,
collapsing the stream into a slow request/response ping-pong (multi-second lag). Keep the flush.

## Authoritative batch pass

On Stop, the continuous clip is uploaded to `POST /recording_sessions/:id/finalize`, the session
moves `recording → processing`, and `ProcessRecordingSessionJob` runs the normal pipeline
([audio-pipeline.md](audio-pipeline.md)):

1. Normalize non-MP3 input to MP3 (`ffmpeg`).
2. **Voxtral batch transcription** via
   [`VoxtralTranscriber`](../../../lib/nodl/transcription/voxtral_transcriber.rb) with
   `diarize: true` and `timestamp_granularities: ["segment"]` (Mistral requires `["segment"]` when
   diarization is on).
3. Build the **display transcript as clean flowing prose**: Voxtral emits `speaker_1:` labels in
   both the top-level text and each segment, so the transcriber strips those labels and joins
   segment text — no speaker prefixes, no per-segment newlines. Speaker identity is preserved in the
   structured segments, not in the prose.
4. Generate the document from the clean transcript with Gemini.

### Stored shape

`recording_sessions` columns relevant here:

- `transcript_text` — clean prose, what the document step receives and what older views show.
- `transcript_segments` (jsonb) — `[{ start, end, speaker, text, words: [...] }]` from Voxtral; the
  source for speaker coloring and time↔text mapping.
- `waveform_peaks` (jsonb) + `audio_duration` (float) — precomputed waveform (see below).

## Waveform precompute

Drawing the waveform by downloading and decoding the whole audio in the browser is too slow on poor
networks (a 12-minute clip took ~25 s on simulated Slow 4G). Instead the waveform is **precomputed
on the server** and embedded in the page so it draws on the first frame with zero download/decode.

- [`Nodl::Audio::WaveformExtractor`](../../../lib/nodl/audio/waveform_extractor.rb) runs `ffmpeg` to
  stream mono PCM and reduces it to **320 normalized peak values (0..1)** plus the duration. It
  streams in chunks, so memory stays bounded even for multi-hour audio, and a failure degrades to an
  empty waveform rather than failing the recording.
- The pipeline stores `waveform_peaks` + `audio_duration` on the session.
- Backfill for pre-existing recordings: `bin/rails recording_sessions:backfill_waveforms`.

## Audio playback & synced transcript

The recording-session page ([`recording_sessions/show.html.erb`](../../../app/views/recording_sessions/show.html.erb))
renders a full-width player below the Transcript/Document cards, driven by
[`audio_player_controller.js`](../../../app/javascript/controllers/audio_player_controller.js):

- **Controls:** play/pause, volume, and a clickable waveform timeline (Lucide icons, not emojis).
- **Waveform** uses the precomputed `waveform_peaks`; client-side fetch+decode remains only as a
  fallback for recordings without stored peaks. Bars are tinted by the active speaker; gaps carry the
  previous speaker's color (no stray accent-colored bars).
- **Transcript** ([`_interactive_transcript.html.erb`](../../../app/views/recording_sessions/_interactive_transcript.html.erb))
  is a compact block. Consecutive segments from one speaker flow as a single paragraph; a new
  paragraph starts only on a speaker change.
- **Two-way sync:** click a segment to seek; during playback/scrub the current segment is highlighted
  **in the speaker's color** and scrolled into view.
- **Speaker styling only when >1 speaker:** distinct color per speaker, segments underlined in that
  color, a "N speakers" legend, and speaker-tinted waveform. Single-speaker recordings are plain text
  with a neutral highlight. Helper logic:
  [`RecordingSessionsHelper`](../../../app/helpers/recording_sessions_helper.rb).

## Dashboard live updates

`recording_sessions.status` adds a `recording` state (before final audio exists). While finalizing,
the model broadcasts a replace of only the transcript **status** sub-panel, so the live preview text
stays visible; on completion it swaps in the final transcript styled like the live text. See
[dashboard.md](dashboard.md).

## Key files

```text
app/javascript/controllers/audio_recorder_controller.js   # capture + live preview rendering
app/javascript/controllers/audio_player_controller.js     # playback + waveform + transcript sync
app/assets/javascripts/audio_pcm_worklet.js               # 16 kHz mono PCM frames
app/channels/live_transcription_channel.rb                # Action Cable proxy (fast + slow streams)
lib/nodl/providers/mistral_realtime_client.rb             # outbound Voxtral realtime WebSocket
lib/nodl/transcription/voxtral_transcriber.rb             # batch diarized transcription
lib/nodl/audio/waveform_extractor.rb                      # ffmpeg → 320 peaks + duration
app/helpers/recording_sessions_helper.rb                  # speaker colors / multi-speaker / label strip
app/views/recording_sessions/_interactive_transcript.html.erb
app/views/recording_sessions/show.html.erb
```

## Config (env)

```text
NODL_VOXTRAL_MODEL=voxtral-mini-latest
NODL_VOXTRAL_REALTIME_MODEL=voxtral-mini-transcribe-realtime-2602
NODL_VOXTRAL_REALTIME_FAST_DELAY_MS=240
NODL_VOXTRAL_REALTIME_SLOW_DELAY_MS=2400
NODL_GEMINI_TRANSFORMER_MODEL=gemini-3.1-flash-lite
MISTRAL_API_KEY=...   # server-side only; never sent to the browser
GEMINI_API_KEY=...    # document transformation only
```

## Failure modes

- **No AudioWorklet / realtime fails:** recording continues; you simply get less/no live preview. The
  batch pass and document still run.
- **Realtime socket error:** the channel transmits an error; the browser stops the preview and notes
  the final transcript will still be generated.
- **Waveform extraction fails:** stored as empty; the player falls back to client-side decode (or a
  flat, still-seekable timeline). The recording is not failed.
- **Batch pass fails:** session marked `failed` with a message (unchanged).

## Testing

Mistral and Gemini are mocked; ffmpeg waveform extraction is tested against a tone generated by
ffmpeg (not the 66-byte placeholder fixture), and faked in pipeline/processor tests.

- `LiveTranscriptionChannel` authorization + event forwarding (outbound socket stubbed).
- `VoxtralTranscriber` segment/timestamp normalization and clean-prose transcript (labels stripped).
- `WaveformExtractor` real-audio peaks/duration + graceful handling of unreadable input.
- Pipeline/processor persist `transcript_segments`, `waveform_peaks`, `audio_duration`.
- Integration: the show page renders the player, clickable cues, speaker-count legend, per-speaker
  cue colors, and embedded waveform peaks.

```sh
make test
make lint
```
