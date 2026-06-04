# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.2.0] - 2026-06-05

### Added

- **Central Dashboard & Audio Recording Area:**
  - Redesigned the dashboard into a unified "Record-to-Document" hub for seamless microphone voice recording and audio file uploads within the current workspace context.
  - Added a voice-reactive aura in the recording area to provide instant visual feedback on audio level/voice activity during microphone recording.
  - Added automatic generation of descriptive, timestamp-based titles for new recording sessions.
- **Live Transcription with Mistral Voxtral:**
  - Added live transcription directly in the browser during microphone recording via ActionCable and WebSockets, powered by Mistral Voxtral (leveraging dual streams for a low-latency fast preview and an authoritative slow stream).
  - Implemented a robust fallback system: if live streaming fails, the final authoritative transcript and document are still seamlessly processed upon completion.
- **Interactive Audio Player & Bi-directional Sync (Audio-Accessible):**
  - Added a custom-built audio player with full controls (play/pause, seeking, volume adjustment) and speaker-colored waveform visualization.
  - **Text-to-Audio Sync:** Clicking any word or cue in the transcript seeks the audio player to that precise timestamp.
  - **Audio-to-Text Sync:** Playing or seeking audio highlights the corresponding word/segment in the transcript in real-time, scrolling the active cue into view.
  - **Speaker Color-Coding (Diarization):** Assigned distinct colors to speakers in multi-speaker recordings. Speaker segments in both the transcript and the player waveform are tinted/underlined in their respective colors without relying on intrusive text labels. Single-speaker recordings remain clean and color-neutral.
- **Safe & Elegant Document Rendering:**
  - Added secure, typographically-optimized rendering of Markdown documents using `Kramdown` and `@tailwindcss/typography` to format headings, lists, links, emphasis, and paragraphs. Includes HTML sanitization and a safe plain-text fallback.
- **Custom Transformers:**
  - Added support for custom transformation profiles (templates) to flexibly convert generated transcripts into targeted Markdown formats (summaries, action items, meeting notes, etc.).

### Changed

- **Migration to Mistral Voxtral for Transcription:**
  - Migrated the audio transcription pipeline from Google Gemini to Mistral Voxtral for superior diarization, segmentation, and word-level timestamp synchronicity. Gemini continues to be utilized for the subsequent document transformation phase.
- **System and Integration Testing:**
  - Added `chromium` and `chromium-driver` to the development Docker image (`Dockerfile.dev`) to support full end-to-end automated system tests.
  - Added Minitest smoke/integration test coverage for the audio dashboard.
- **Developer Guidelines & Repository Hygiene:**
  - Clarified and updated agent instructions regarding the `private/` directory, treating it as a local, ignored companion repository.

### Fixed

- **Resolved Live Transcription Latency:** Fixed a multi-second delay in real-time Voxtral transcription to ensure rapid preview updates.
- **Fixed Live Preview Text Collapse:** Resolved a visual issue where the live preview text color collapsed or flickered from orange to black.
- **Zeitwerk Autoloading Compatibility:** Fixed a `superclass-mismatch` error by excluding manual libraries from Zeitwerk's autoloader in `config/application.rb`.


## [0.1.1] - 2026-05-30

### Changed

- Renamed repository to `nodl`after copying from hotstone boiler plate project.

### Security

- **S-001 resolved:** Seed credentials can no longer enable account takeover. `db/seeds.rb` now returns early unless `Rails.env.development?` or `ENV["ALLOW_DEMO_SEEDS"] == "1"`, and demo user passwords are generated with `SecureRandom.hex(12)` (printed once to stdout, never stored). Regression tests added in `test/integration/seeds_security_test.rb`. `README.md` and `doc/index.md` updated to remove hardcoded credential references.

---

## [0.1.0] - 2026-02-21

Initial release of the Nodl Rails 8 SaaS boilerplate.

### Added

#### Core Application

- Rails 8 application scaffold with PostgreSQL database.
- Docker Compose setup for local development (`Dockerfile.dev`, `docker-compose.yml` with health checks and environment variable configuration).
- Makefile with developer shortcuts (`make build`, `make up`, `make dev`, `make seed`, `make test`, `make logs`, `make shell`, `make down`).
- `.env.example` documenting all required and optional environment variables.

#### Domain Model

- Multi-tenant domain: `User`, `Workspace`, `Membership` models with associations and validations.
- Role system on `User` (`:admin`, `:user`) and `Membership` (`:owner`, `:member`).
- Workspace subscription fields (`subscription_status`, `subscription_plan`, `subscription_billing_cycle`, `usage_limits`, `usage_consumption`).

#### Authentication & Authorization

- Session-based authentication with `has_secure_password`.
- Registration, login, and logout flows.
- Password complexity enforcement (uppercase, lowercase, digit) in registration.
- Login throttling with failed-attempt tracking via Rails cache.
- `authenticate_user!` and `require_admin!` guards on all protected surfaces.
- Admin namespace (`Admin::UsersController`) at `/admin/users` with audit event logging.

#### Multi-Tenancy

- `current_workspace` resolution scoped to user memberships.
- Workspace switching restricted to workspaces the current user belongs to.

#### Payments (Stripe Placeholder)

- Stripe Checkout placeholder flow: `/payments`, `/payments/checkout`, `/payments/success`, `/payments/cancel`.
- Webhook endpoint at `/payments/webhook`.
- Graceful handling of missing Stripe session URLs.

#### Frontend

- Tailwind CSS + DaisyUI for all UI components.
- DaisyUI stylesheet served locally (no CDN dependency).
- Inter font via local assets.
- Turbo + Stimulus for SPA-like interactions without a full SPA.
- Theme switcher (light/dark) implemented as a Stimulus controller.
- Lucide SVG icons imported locally.
- SSR marketing, dashboard, and admin pages.
- Liveness (`/healthz`) and readiness (`/readyz`) endpoints.

#### Observability

- OpenTelemetry instrumentation with export support for self-hosted SigNoz.

#### Security

- Content Security Policy initializer (`config/initializers/content_security_policy.rb`).
- HTTPS enforcement and host allow-listing in production config.
- Sensitive parameters filtered from logs.
- Security hardening pass (session/cookie settings, header defaults).

#### Testing

- Rails Minitest suite: unit, integration, and system tests.
- End-to-end system tests for authentication and admin user management.
- System tests for marketing pages, payments, and theme switcher (JS-guarded with `JS_SYSTEM_TESTS=1`).
- Stripe checkout/webhook integration tests with stubs (no network required).

#### AI Agent Infrastructure

- `CLAUDE.md` and `AGENTS.md` with project-specific agent collaboration rules.
- Skill generation framework (`.codex/skills/`) with shared scripts.
- Documentation Architect agent — generates structured docs under `doc/`.
- Documentation Auditor agent — audits `doc/` claims against source code.
- Security Auditor skill — runs Brakeman, bundler-audit, importmap audit, produces `doc/security-audit-report.md`.
- Security Hardener agent — applies fixes from the audit report.
- User Story Creator skill — scaffolds user story markdown files.
- Merge Feature Into Main agent — safe merge workflow with forced merge commit.
- Lucide icon import skill — imports SVG icons locally without CDN or Node runtime.

#### Documentation

- `README.md` with setup, daily commands, accounts, Stripe config, and AI collaboration workflow.
- `doc/` with architecture, data models, API, authentication, admin, payments, multi-tenancy, testing, and frontend module docs.
- Architecture Decision Records (ADRs) for session-based auth and Solid stack.
- Developer guidelines document (`developer-guidelines.md`).
- Example user story.
