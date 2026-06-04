# Audio-To-Markdown Pipeline

## Purpose

The audio pipeline turns audio into a Markdown document. It began as a console prototype and is now also used by the authenticated dashboard through a database-backed recording-session flow.

The authoritative implemented flow is:

```text
audio.mp3 -> Voxtral transcription -> transcript.md + transcript.segments.json -> filesystem transformer -> Gemini document transformation -> document.md
```

Dashboard processing stores the original uploaded or recorded audio in Active Storage, normalizes non-MP3 inputs to MP3 with `ffmpeg`, runs this pipeline in an Active Job, and saves transcript/document content back to database records. Microphone recordings also have a live preview track: the browser streams 16 kHz mono PCM frames through a Rails Action Cable proxy to Mistral Voxtral realtime transcription. The proxy opens two Mistral realtime streams: a fast low-delay stream for orange provisional text and a slower stream for stable normal-color text. The final whole-file Voxtral batch pass remains the source of truth and replaces the preview when complete. The batch request asks for segment timestamp granularity because Mistral requires `["segment"]` when diarization is enabled.

## Entry Point

The CLI entry point is:

```text
bin/nodl
```

The browser entry point is `GET /dashboard`, where an authenticated user can upload audio or record from the microphone.

It is Rails-aware and loads the application environment before running. The main command is:

```sh
MISTRAL_API_KEY=... GEMINI_API_KEY=... docker compose exec -e MISTRAL_API_KEY -e GEMINI_API_KEY web bin/nodl run path/to/audio.mp3 --transformer default
```

`transcribe` is currently accepted as an alias for the same full pipeline:

```sh
MISTRAL_API_KEY=... GEMINI_API_KEY=... docker compose exec -e MISTRAL_API_KEY -e GEMINI_API_KEY web bin/nodl transcribe path/to/audio.mp3 --transformer default
```

Supported options:

```text
--transformer HANDLE
--work-dir PATH
--transcriber-model MODEL
--transformer-model MODEL
```

Default models:

```text
NODL_VOXTRAL_MODEL=voxtral-mini-latest
NODL_VOXTRAL_REALTIME_MODEL=voxtral-mini-transcribe-realtime-2602
NODL_VOXTRAL_REALTIME_FAST_DELAY_MS=240
NODL_VOXTRAL_REALTIME_SLOW_DELAY_MS=2400
NODL_GEMINI_TRANSFORMER_MODEL=gemini-3.1-flash-lite
```

If the environment variables are absent, the CLI defaults transcription to `voxtral-mini-latest` and document transformation to `gemini-3.1-flash-lite`.

## Implementation Shape

The reusable library code lives under `lib/nodl/`:

```text
lib/nodl/
  cli.rb
  pipeline.rb
  audio_input.rb
  working_directory.rb
  transcription/voxtral_transcriber.rb
  audio/waveform_extractor.rb
  transformation/transformer_repository.rb
  transformation/gemini_document_transformer.rb
  providers/gemini_client.rb
  providers/mistral_client.rb
  providers/mistral_realtime_client.rb
```

The important responsibilities are:

- `Nodl::Cli` parses commands and options, then prints generated output paths.
- `Nodl::Pipeline` orchestrates the run.
- `Nodl::AudioInput` validates the source file. Only `.mp3` is supported.
- `Nodl::WorkingDirectory` creates a run folder.
- `Nodl::Transcription::VoxtralTranscriber` asks Mistral Voxtral for a diarized transcript with segment timestamps, then strips Voxtral's `speaker_1:` labels to produce clean flowing prose (speaker identity is kept in the structured segments).
- `Nodl::Audio::WaveformExtractor` runs `ffmpeg` to reduce the audio to ~320 normalized peak values plus duration, so the player can draw the waveform instantly without a client-side download/decode.
- `Nodl::Transformation::TransformerRepository` loads transformer instructions and templates from disk.
- `Nodl::Transformation::GeminiDocumentTransformer` combines default instructions, transformer instructions, templates, and transcript into the document prompt.
- `Nodl::Providers::GeminiClient` wraps Gemini REST calls with Ruby standard library HTTP and JSON APIs.
- `Nodl::Providers::MistralClient` wraps the Voxtral batch transcription endpoint.
- `Nodl::Providers::MistralRealtimeClient` wraps the outbound Voxtral realtime WebSocket used by `LiveTranscriptionChannel`.

`lib/nodl` is manually required library code. It is excluded from Rails Zeitwerk autoloading in [`config/application.rb`](../../../config/application.rb), along with `lib/observability`, because these libraries define their own require graph and do not follow Rails' one-constant-per-file convention.

## Filesystem Transformers And Output Types

Transformers are local folders. The folder name is the transformer handle:

```text
transformers/
  default/
    instructions.md
    templates/
      example.md
```

`instructions.md` is required. Templates are optional and currently limited to plain text or Markdown files:

```text
.md
.markdown
.txt
```

The committed prototype includes only `transformers/default`. Other transformer folders are treated as local experiments and ignored by git.

The dashboard presents transformer profiles as "Output types" in user-facing copy. Backend model names and columns still use `TransformerProfile` and `transformer_handle`.

To create and use a local transformer:

```sh
mkdir -p transformers/meeting-notes/templates
$EDITOR transformers/meeting-notes/instructions.md
$EDITOR transformers/meeting-notes/templates/example.md

GEMINI_API_KEY=... docker compose exec -e GEMINI_API_KEY web bin/nodl run path/to/audio.mp3 --transformer meeting-notes
```

## Run Outputs

Each run writes a session directory under `work/sessions/` unless `--work-dir` is provided:

```text
work/sessions/<run-id>/
  audio.mp3
  transcript.md
  transcript.segments.json
  document.md
  metadata.json
```

The files mean:

- `audio.mp3`: copied source audio for the run.
- `transcript.md`: clean prose transcript (Voxtral's speaker labels stripped; speakers retained in the segments json).
- `transcript.segments.json`: structured segment/word timestamp data returned by Voxtral.
- `document.md`: Markdown document generated from the transcript and transformer.
- `metadata.json`: source path, output paths, transformer handle, model names, transcript language/audio duration, and timestamps.

The generated `work/` directory is ignored by git.

## Dashboard Persistence And Live Updates

The UI flow adds database records around the pipeline:

- `RecordingSession` belongs to a workspace and creator, stores status, source kind, transformer handle, transcript text, structured transcript segments, precomputed `waveform_peaks` + `audio_duration`, error message, and processing timestamps.
- `Document` belongs to a workspace and recording session, and stores generated Markdown content.
- `TransformerProfile` belongs to a workspace and points at filesystem transformer folders. Each workspace gets one default profile for `transformers/default`.

`RecordingSession` attaches the original audio through Active Storage and attaches a normalized MP3 only when `ffmpeg` conversion is required.

`RecordingSession` also owns the dashboard live-update contract. Its status transition helpers broadcast one Turbo Stream replacement for `dashboard_activity` on `[workspace, :dashboard]`. The activity feed renders recent sessions and links to a generated document when a completed session has one.

Microphone recording sessions can start in `recording` status before the final audio exists. During that state, `LiveTranscriptionChannel` authenticates the user/workspace/session, proxies PCM frames to Mistral Voxtral realtime transcription, and transmits text deltas back to the browser. `POST /recording_sessions/:id/finalize` attaches the uninterrupted full clip, moves the session into processing, and enqueues the normal `ProcessRecordingSessionJob`.

## Prompting

Voxtral batch transcription runs with diarization enabled and requests segment timestamp granularity. Voxtral returns `speaker_1:` labels in the text; the pipeline **strips** them and feeds clean prose to the document prompt, while keeping speaker identity in the structured segments. Voxtral realtime preview does not support diarization, so preview text is plain and not saved as the final transcript. The realtime preview architecture and the audio player are documented in [live-transcription.md](live-transcription.md).

The document transformation prompt is assembled from:

```text
default document instructions
transformer handle
transformer instructions.md
templates/*
raw transcript
```

The transformation step returns Markdown only.

## Testing And Verification

Automated tests live under `test/lib/nodl/` and mock Mistral/Gemini behavior. They cover:

- audio input validation
- work session paths
- transformer loading and errors
- prompt assembly
- Mistral and Gemini client request construction
- Voxtral segment/timestamp normalization
- Action Cable live-transcription authorization and event forwarding
- CLI failures
- pipeline file creation and metadata

Relevant commands:

```sh
docker compose exec web bin/rails test test/lib/nodl
make test
make lint
```

A live smoke test can be run with private data and must not be required for CI:

```sh
set -a
source private/.env
set +a

docker compose exec -e GEMINI_API_KEY web bin/nodl run private/test-data/interview-osta-first-60s.mp3 --transformer default
```

## Current Boundaries

The current implementation intentionally does not include:

- multiple documents per recording session
- document versioning
- output-type CRUD
- re-transforming a recording as another output type
- transformer snapshotting
- PDF or Word template parsing

Those concerns belong to a later MVP implementation after the main pipeline behavior has been validated.
