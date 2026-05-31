# Testing Guidelines

## Purpose

Nodl should have tests that make product behavior trustworthy without freezing every implementation detail. This is especially important when code is generated or changed with AI assistance: the test suite should prove that important user outcomes, tenant boundaries, and processing workflows still work after changes.

The goal is not maximum test count. The goal is a small, meaningful suite that catches regressions users would notice and failures developers would struggle to debug.

## Testing Philosophy

Prefer behavior tests over implementation tests.

Good tests answer questions like:

- Can a real user complete the workflow?
- Is data scoped to the correct workspace?
- Does the model enforce the domain rule?
- Does the job persist the right state when the pipeline succeeds or fails?
- Does the UI expose stable hooks for important interactions?

Avoid tests that primarily assert:

- private method structure;
- exact layout details;
- CSS class arrangements unrelated to behavior;
- copy that is likely to change;
- framework internals.

Use `data-testid` for important UI anchors when text, layout, or visual hierarchy may change. Keep these IDs stable and semantic.

## Preferred Test Layers

### System Tests

Use system tests for product promises. These should cover a small number of full user flows through Rails views and forms.

For Nodl, durable system coverage should include:

- a user can sign in and reach the dashboard;
- the dashboard hub renders the recording form, output-type selector, activity feed, and stream source;
- uploading audio creates a recording session and enqueues processing;
- processing, completed, and failed activity states are visible;
- completed sessions link to generated documents;
- failed sessions link to detail/error context;
- workspace switching keeps the user in the correct tenant context.

Most system tests should use the fast `rack_test` driver. It exercises the full Rails request/render/form stack without launching a browser.

Use real browser/JavaScript system tests only for behavior that requires JavaScript, such as Stimulus recording controls or upload auto-submit. Keep this layer small and guard it with an explicit opt-in flag when appropriate, such as `JS_SYSTEM_TESTS=1`.

### Integration Tests

Use integration tests for HTTP and controller boundaries.

For Nodl, integration tests should cover:

- authenticated creation of recording sessions;
- invalid or unsupported audio rejection;
- selected output type must belong to the current workspace;
- recording-session and document access is tenant-scoped;
- failed processing paths redirect or render useful user feedback.

Integration tests are the right place to verify route behavior, redirects, strong params, and authorization boundaries without depending on page layout.

### Model Tests

Use model tests for domain rules and durable state transitions.

For Nodl, model tests should cover:

- required associations and attachments;
- accepted statuses and source kinds;
- validation of audio size and content type;
- one default output type per workspace;
- `mark_processing!`, `mark_completed!`, and `mark_failed!`;
- completed sessions create the expected document;
- Turbo broadcast targets for live dashboard updates.

Model tests should not duplicate every Active Record association mechanically unless the association carries important behavior.

### Job And Service Tests

Use job and service tests for orchestration around external systems.

For audio processing:

- stub Gemini calls;
- stub `ffmpeg` command execution in unit tests;
- assert original audio is downloaded;
- assert non-MP3 input is normalized;
- assert the pipeline receives the expected output type;
- assert transcript and document content are persisted;
- assert errors mark the session failed.

Do not require live network access, real Gemini calls, or real external conversion in normal CI/local test runs. A live smoke test with private data can exist as a manual check, but it must not be required for the default suite.

## Dashboard Smoke-Test Standard

The dashboard is expected to evolve visually. Tests should protect the stable contract, not the exact composition.

Smoke tests should assert:

- `data-testid="record-hero"` exists;
- the recording form has `data-controller~="audio-recorder"`;
- the record button, upload input, output-type selector, output-type panel, and activity feed exist;
- the activity feed can render `processing`, `completed`, and `failed` sessions;
- completed items expose a document link;
- failed items expose a session detail link;
- the dashboard subscribes to the workspace Turbo stream.

Smoke tests should avoid asserting:

- exact card layout;
- exact hero copy beyond essential accessibility labels;
- animation details;
- decorative styling;
- exact order of non-critical elements.

## AI-Assisted Change Rule

When AI-generated code changes behavior, add or update a test at the highest useful level before accepting the change.

Use this mapping:

- User flow changes: system or integration test.
- Controller or route changes: integration test.
- Domain state changes: model test.
- Job/service orchestration changes: job or service test with external calls stubbed.
- JavaScript behavior changes: small JS system test or focused controller-level browser check.
- Copy/layout-only changes: smoke test stable `data-testid` hooks only if the changed element is important to the workflow.

If a regression was found manually, add a regression test unless the behavior is impractical to automate at the current layer. If it cannot be automated, document why in the handoff.

## Quality Gates

Before handing off behavior changes:

```sh
make test
make lint
```

For dashboard JavaScript changes, additionally consider:

```sh
JS_SYSTEM_TESTS=1 docker compose exec web bin/rails test test/system/audio_recorder_js_test.rb
```

If a required check cannot run or fails for an unrelated reason, report the exact blocker and the targeted tests that did pass.
