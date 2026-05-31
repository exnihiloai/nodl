# Audio-To-Markdown Prototype Pipeline

## Purpose

The audio pipeline turns audio into a Markdown document. It began as a console prototype and is now also used by the authenticated dashboard through a database-backed recording-session flow.

The implemented flow is:

```text
audio.mp3 -> Gemini transcription -> transcript.md -> filesystem transformer -> Gemini document transformation -> document.md
```

Dashboard processing stores the original uploaded or recorded audio in Active Storage, normalizes non-MP3 inputs to MP3 with `ffmpeg`, runs this pipeline in an Active Job, and saves transcript/document content back to database records.

## Entry Point

The CLI entry point is:

```text
bin/nodl
```

The browser entry point is `GET /dashboard`, where an authenticated user can upload audio or record from the microphone.

It is Rails-aware and loads the application environment before running. The main command is:

```sh
GEMINI_API_KEY=... docker compose exec -e GEMINI_API_KEY web bin/nodl run path/to/audio.mp3 --transformer default
```

`transcribe` is currently accepted as an alias for the same full pipeline:

```sh
GEMINI_API_KEY=... docker compose exec -e GEMINI_API_KEY web bin/nodl transcribe path/to/audio.mp3 --transformer default
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
NODL_GEMINI_TRANSCRIBER_MODEL=gemini-3.1-flash-lite
NODL_GEMINI_TRANSFORMER_MODEL=gemini-3.1-flash-lite
```

If the environment variables are absent, the CLI defaults both steps to `gemini-3.1-flash-lite`.

## Implementation Shape

The prototype lives under `lib/nodl/`:

```text
lib/nodl/
  cli.rb
  pipeline.rb
  audio_input.rb
  working_directory.rb
  transcription/gemini_transcriber.rb
  transformation/transformer_repository.rb
  transformation/gemini_document_transformer.rb
  providers/gemini_client.rb
```

The important responsibilities are:

- `Nodl::Cli` parses commands and options, then prints generated output paths.
- `Nodl::Pipeline` orchestrates the run.
- `Nodl::AudioInput` validates the source file. Only `.mp3` is supported.
- `Nodl::WorkingDirectory` creates a run folder.
- `Nodl::Transcription::GeminiTranscriber` uploads audio and asks Gemini for a faithful transcript.
- `Nodl::Transformation::TransformerRepository` loads transformer instructions and templates from disk.
- `Nodl::Transformation::GeminiDocumentTransformer` combines default instructions, transformer instructions, templates, and transcript into the document prompt.
- `Nodl::Providers::GeminiClient` wraps Gemini REST calls with Ruby standard library HTTP and JSON APIs.

## Filesystem Transformers

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
  document.md
  metadata.json
```

The files mean:

- `audio.mp3`: copied source audio for the run.
- `transcript.md`: raw transcript generated from the audio.
- `document.md`: Markdown document generated from the transcript and transformer.
- `metadata.json`: source path, output paths, transformer handle, model names, Gemini file URI, and timestamps.

The generated `work/` directory is ignored by git.

## Dashboard Persistence

The UI flow adds database records around the pipeline:

- `RecordingSession` belongs to a workspace and creator, stores status, source kind, transformer handle, transcript text, error message, and processing timestamps.
- `Document` belongs to a workspace and recording session, and stores generated Markdown content.
- `TransformerProfile` belongs to a workspace and points at filesystem transformer folders. Each workspace gets one default profile for `transformers/default`.

`RecordingSession` attaches the original audio through Active Storage and attaches a normalized MP3 only when `ffmpeg` conversion is required.

## Prompting

The transcription prompt asks Gemini to produce a faithful transcript, preserve the speaker language, add speaker tags when multiple speakers are present, add punctuation and paragraphs where helpful, avoid summarization, and return only transcript text.

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

Automated tests live under `test/lib/nodl/` and mock Gemini behavior. They cover:

- audio input validation
- work session paths
- transformer loading and errors
- prompt assembly
- Gemini client request construction
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

- document identity
- document versioning
- transformer snapshotting
- PDF or Word template parsing

Those concerns belong to a later MVP implementation after the main pipeline behavior has been validated.
