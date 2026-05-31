# Dashboard Audio-To-Document Hub

## Purpose

The authenticated dashboard is the product entry point for turning spoken or uploaded audio into a generated Markdown document. It intentionally presents user-facing language around documents and output types while preserving the existing backend vocabulary where it is already encoded in models and library classes.

Primary source files:

- [`app/views/dashboard/show.html.erb`](../../../app/views/dashboard/show.html.erb)
- [`app/views/dashboard/_activity.html.erb`](../../../app/views/dashboard/_activity.html.erb)
- [`app/controllers/dashboard_controller.rb`](../../../app/controllers/dashboard_controller.rb)
- [`app/controllers/recording_sessions_controller.rb`](../../../app/controllers/recording_sessions_controller.rb)
- [`app/models/recording_session.rb`](../../../app/models/recording_session.rb)
- [`app/javascript/controllers/audio_recorder_controller.js`](../../../app/javascript/controllers/audio_recorder_controller.js)

## User-Facing Flow

The dashboard centers on one action: create a document from audio.

Implemented paths:

1. User opens `GET /dashboard`.
2. Dashboard resolves the current workspace and ensures a default `TransformerProfile`.
3. User records microphone audio or uploads an audio file.
4. User chooses an output type.
5. Form posts to `POST /recording_sessions`.
6. A `RecordingSession` is created and `ProcessRecordingSessionJob` is enqueued.
7. The job normalizes audio when required, runs the Gemini-backed pipeline, and marks the session completed or failed.
8. The dashboard activity feed updates through Turbo Streams.

The UI should continue to use "Output type" for users. "Transformer" remains an internal implementation term because `TransformerProfile`, `transformer_handle`, and filesystem transformer folders already exist.

## Dashboard Data Contract

`DashboardController#show` prepares only the data needed by the hub:

- `@workspace`: current tenant context.
- `@transformer_profiles`: active output types for the workspace, default first.
- `@recording_sessions`: recent sessions for the unified activity feed.
- `@recording_session`: unsaved form object with the default transformer handle.

The controller deliberately does not load a separate finished-documents collection. The activity feed derives document links from each completed recording session's `has_one :document` association.

## Activity Feed

The activity feed is rendered by [`app/views/dashboard/_activity.html.erb`](../../../app/views/dashboard/_activity.html.erb) and replaced as one unit.

Stable DOM and stream contract:

- Turbo stream: `[workspace, :dashboard]`
- Replace target: `dashboard_activity`
- Partial: `dashboard/activity`
- Local: `recording_sessions`

`RecordingSession#broadcast_dashboard_activity` is called from status transition helpers:

- `mark_processing!`
- `mark_completed!`
- `mark_failed!`

The feed is intentionally session-first. Completed sessions expose an "Open document" action when `session.document` exists; failed sessions link back to the recording session detail page for error context.

## Recording Modes

The same Rails form handles both upload and microphone capture.

Upload mode:

- Uses the visible file input in the dashboard form.
- Sets `recording_session[source_kind]` to `upload`.
- Auto-submits after a file is selected.

Microphone mode:

- Uses `MediaRecorder` in [`audio_recorder_controller.js`](../../../app/javascript/controllers/audio_recorder_controller.js).
- Chooses the first supported compact MIME type from WebM/Opus, OGG/Opus, MP4, or AAC.
- Uses a hidden file input to attach the recorded blob to `recording_session[original_audio]`.
- Sets `recording_session[source_kind]` to `microphone`.
- Auto-submits after recording stops.

The browser should not create WAV audio by default. The backend keeps WAV support as an accepted fallback, but `ffmpeg` normalizes non-MP3 inputs to MP3 for pipeline processing.

## Voice Aura

The recording aura is progressive enhancement, not core recording logic.

Implementation:

- The Stimulus controller creates a Web Audio `AnalyserNode` from the microphone stream.
- RMS level is smoothed and written to CSS variables `--aura-scale` and `--aura-opacity`.
- Styles live in [`app/assets/tailwind/application.css`](../../../app/assets/tailwind/application.css) under `.voice-aura`.
- `prefers-reduced-motion: reduce` disables morph animation while preserving a quieter level response.

Recording must continue if the visualizer fails. `startVisualizer` catches errors and shuts down only visualization resources.

## Workspace And Account Controls

Workspace switching, upgrade, and logout live in the account dropdown in [`app/views/shared/_logged_in_nav.html.erb`](../../../app/views/shared/_logged_in_nav.html.erb). Dashboard work should not reintroduce a prominent page-level logout or workspace switcher unless the product direction changes.

The dashboard must keep all queries scoped through `current_workspace`. Cross-workspace access remains forbidden by controller lookups on the current workspace association.

## Backend Boundaries

The dashboard does not run the audio pipeline inline. `RecordingSessionsController#create` persists a session and enqueues `ProcessRecordingSessionJob`.

Pipeline responsibilities remain separated:

- `RecordingSessionProcessor` downloads Active Storage audio, normalizes it, runs `Nodl::Pipeline`, and persists transcript/document results.
- `Nodl::Audio::Normalizer` wraps `ffmpeg`.
- `Nodl::Pipeline` and `lib/nodl/**` remain reusable library code for CLI and dashboard processing.

Important autoloading constraint:

`lib/nodl` and `lib/observability` are excluded from Rails Zeitwerk autoloading in [`config/application.rb`](../../../config/application.rb). They are manually required libraries and do not follow Rails' one-constant-per-file autoloading convention.

## Deferred Product Capabilities

The current model shape deliberately limits what the dashboard can do:

- `RecordingSession has_one :document`, so generating multiple documents from one recording is not supported yet.
- There is no output-type CRUD UI or transformers controller.
- "Transform again as another output type" requires data model changes before UI work.
- Document editing, versioning, export, and deletion are outside the current dashboard contract.

## Verification

Relevant automated coverage:

- `test/models/recording_session_test.rb` covers dashboard activity broadcast targets.
- `test/system/dashboard_tenancy_test.rb` covers dashboard rendering and recording creation.
- `test/system/audio_recorder_js_test.rb` is guarded by `JS_SYSTEM_TESTS=1` for browser recording behavior where practical.

For implementation changes, run:

```sh
make test
make lint
```
