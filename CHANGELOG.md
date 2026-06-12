# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Technical
- **OAuth Config Alerts:** When Google sign-in fails because of configuration (for example `redirect_uri_mismatch`, `invalid_client`, `csrf_detected`, or missing `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`), operators can receive a throttled Telegram alert via the existing telemetry notifier — so misconfigured OAuth shows up before users report it.

## [0.15.1] - 2026-06-12

### Fixed
- **Marketing Site Restored in Production:** Deployments now bake in the full landing page and marketing copy from the companion repository again, so production shows the real homepage instead of the generic open-source sign-in shell.

### Technical
- GitLab CI and `make build-prod` now fetch `private/views` and `private/locales` from the companion repo and verify that `private/views/pages/home.html.erb` is present before building the production image.

## [0.15.0] - 2026-06-12

### Added
- **Continue with Google:** You can now sign in or create an account with Google on the login and registration pages — one click instead of typing a password. If you already have a Nodl account with the same verified email, Google sign-in links to it automatically. New Google users get a workspace and land on the dashboard right away. Available in English and German when your operator has configured Google OAuth.

### Changed
- **Login and Registration Layout:** Both pages now lead with a Google button and an “or” divider before the email-and-password form, so you can pick whichever sign-in method you prefer.

## [0.14.0] - 2026-06-12

### Added
- **Landing Pages for Your Profession:** Nodl now offers dedicated pages for doctors, dentists, coaches, journalists, journal keepers, and overthinkers — each explaining how speech-to-document fits that workflow, with its own examples and calls to action. Find them in the site footer or at paths like `/fuer/aerzte` and `/fuer/coaches`. Available in English and German when your operator has published the marketing content.

- **A Richer Home Page:** The landing page now walks visitors through Nodl's value — before-and-after examples, a trust strip highlighting security and privacy, product features, pricing, and FAQs — so new visitors understand what they get before signing up. An animated hero spectrogram illustrates the journey from raw speech to finished document.


### Technical
- Added `PrivateContent` (`lib/private_content.rb`) to detect mounted private marketing templates and locales; `ApplicationController` prepends `private/views` per request and `private/locales` are loaded into `I18n`.
- Marketing templates moved from `app/views/pages/` to `private/views/pages/`; marketing translation keys moved from `config/locales/` to `private/locales/`.
- `.dockerignore` now allows `private/views` and `private/locales` in production image builds (alongside the existing `private/legal` and `private/initializers` exceptions).
- Sitemap generation includes marketing URLs only when their private templates are present.
- Landing-page icons are bundled locally (Lucide SVGs); `PagesHelper` centralises product-feature and plan-limit copy for marketing partials.
- Added `layouts/_theme_boot_script` and a `reveal` Stimulus controller for scroll-in animations on marketing sections.


## [0.13.2] - 2026-06-10

### Technical
- The browser JS system tests (microphone recorder, clipboard, theme switcher) are now part of the handoff gate: `make test` runs the system tests with `JS_SYSTEM_TESTS=1`, so `make check` — and the CI `check` job on every merge request — executes them; previously they only ran when started by hand. A `make test-js` convenience target runs the system-test step alone.
- `config/recurring.yml` is now validated in the test suite: a recurring job entry whose `class:` doesn't resolve, whose `command:` doesn't parse, or whose `schedule:` is invalid fails `make check` with a message naming the bad entry, instead of failing silently at runtime in production.
- Defaults shared by the CLI and the web pipeline (transcriber/transformer models, default format handle, their env-var overrides) are consolidated into a single definition point, `Nodl::Defaults` (`lib/nodl/defaults.rb`), removing duplicated constants in `lib/nodl/cli.rb`, `app/services/recording_session_processor.rb`, and `app/models/transformer_profile.rb`.
- New `make reset-dev` resets local development to a clean seeded state in one command (wipes uploads and work sessions, reloads the schema, reseeds).
- Entries in `.database_consistency.todo.yml` now carry dated rationales.
- The browser system tests no longer open real websockets to the Mistral realtime API (which streamed test audio and burned quota whenever `MISTRAL_API_KEY` was set locally): the live-transcription client factory is stubbed in the browser test base class, keeping the suite fully offline and removing the async teardown warning at the end of `make test`.


## [0.13.1] - 2026-06-10

### Technical
- Encryption at rest is now strictly enforced: `support_unencrypted_data` is off, so a plaintext value in an encrypted column raises instead of being silently tolerated. All environments were verified fully encrypted beforehand; operators upgrading older instances find the backfill procedure in `doc/design-output/security/data-encryption.md`.


## [0.13.0] - 2026-06-09

### Added
- **Your Data Is Now Encrypted at Rest:** Everything you store in Nodl — transcripts, generated documents, recording titles, uploaded audio, format instructions, and workspace settings — is now encrypted in the database and on disk. Every uploaded file additionally gets its own encryption key, so even direct access to the storage would not reveal your content. Together with the encrypted connections Nodl already used (HTTPS, secure websockets), your data is protected both in transit and at rest. Playback, downloads, and all everyday features work exactly as before.



## [0.12.0] - 2026-06-08

### Added
- **Accept Terms and Privacy When You Sign Up:** When your operator has published legal documents, registration now includes a required checkbox linking to the Terms and Conditions and Privacy Policy. Your agreement is recorded with the document version, timestamp, and request details so there is an auditable consent history when policies are updated.
- **AI Transparency Page:** A new page at `/ki-transparenz` explains how Nodl uses AI — what data is processed, which models are involved, and your rights. It appears in the “Related documents” section on the Privacy Policy and Terms pages when the operator has published the document.
- **Subprocessor Register:** A new page at `/subprozessoren` lists third-party subprocessors (hosting, email, AI providers, and similar). It is linked from the Privacy Policy and Security pages when published, so you can see who processes data on the operator’s behalf.
- **Security Measures (TOMs):** A new page at `/sicherheit` describes technical and organizational security measures. It is linked from the Privacy Policy and Subprocessor Register when published.
- **Related Documents on Legal Pages:** Privacy, Terms, AI Transparency, Security, and Subprocessor pages now show a “Related documents” section at the bottom, linking to other published legal pages that belong together — without cluttering the site footer.



## [0.11.0] - 2026-06-08

### Added
- **Your Recordings Now Know the Date and Time:** When you mention "today", "right now", or a day of the week without saying the actual date, your generated documents and titles can now fill it in for you. Nodl remembers exactly when each recording was made — including the weekday — and references it only when your words or your output type call for it, so neutral notes stay clean and untouched.

- **Times Shown in Your Local Time Zone:** New recordings capture your device's time zone, so both the document text and the timestamps on the document and recording pages now show your local time (for example, 21:00 instead of 19:00 UTC). Existing recordings made before this update continue to display in UTC.



## [0.10.2] - 2026-06-07

### Technical
- Production deploy (`make deploy`) now uses a registry-backed build cache (`--cache-from`/`--cache-to` against `$DEPLOY_IMAGE:buildcache`), so repeat deploys reuse layers instead of rebuilding gems and assets from scratch.


## [0.10.1] - 2026-06-07

### Technical
- Added a GitLab CI/CD pipeline (`.gitlab-ci.yml`): merge requests build the real production image (including the private companion-repo content) and run `make check` + `make audit`; merges to `main` deploy via `make deploy`; a scheduled job reclaims Docker disk on the runner. Adds `docker-compose.ci.yml` and a `make build-prod` target.


## [0.10.0] - 2026-06-07

### Added
- **Show Password While You Type:** You can now tap the eye button next to any password field — on login, registration, and admin user forms — to reveal or hide what you typed, so you can double-check entries before submitting. Only the display changes in your browser; passwords are never stored in plain text.


## [0.9.5] - 2026-06-07

### Fixed
- **Signed-in Visits Go Straight to the Dashboard:** Returning to the Nodl home page while already signed in now takes you directly to your dashboard, so you no longer see signup prompts meant for new visitors.


## [0.9.4] - 2026-06-06

### Added
- **Browse What's New in the App:** A new Changelog page at `/changelog` shows every release in a scrollable board grouped by week. Each version appears as a card with a preview; tap or click to open the full notes in a modal. You can link directly to a release (for example `/changelog/v0.9.3`), and the About page now includes a Changelog link. Available in English and German.
- **Search Engines Can Find Public Pages:** The site now serves a dynamic `/sitemap.xml` listing indexable marketing pages (home, about, try-now, login, register) and any configured legal pages (imprint, privacy, terms). `/robots.txt` allows crawlers and points them to the sitemap, replacing the old static file.

### Technical
- `Changelog` parses `CHANGELOG.md` at runtime with short-lived caching; the changelog page is marked `noindex` so it stays out of search results.
- Added `Sitemap` builder, `SitemapController`, `RobotsController`, and integration tests for sitemap and robots endpoints.


## [0.9.3] - 2026-06-06

### Changed
- **Account Menu Cleanup:** Shortened workspace names in the account menu by removing the redundant "Workspace" suffix (e.g. "Alpha Workspace" becomes "Alpha") and added hover tooltips and text truncation so long email addresses and workspace names no longer distort the dropdown layout.
- **404 Layout Refinement:** Redesigned the custom 404 page hero graphic to avoid overlapping text and icons on smaller viewports, and improved the transcript box and hint text responsiveness.

### Fixed
- **Safari Dropdown Focus Issues:** Transitioned dropdowns (language switcher and account navigation) from `:focus-within` CSS-based interactions to robust details/summary components managed via a Stimulus controller, fixing an issue where menus wouldn't reliably close or toggle in Safari.
- **Standardized Full-Area Click Targets:** Replaced old CSS-focus-based dropdowns with HTML `<details>` and `<summary>` tags coupled with a dedicated Stimulus controller to make sure clicking anywhere inside a highlighted option (for language switches, workspace switches, or logout) acts as a click target, preventing missed clicks.

### Technical
- Added system tests under `test/system/locale_switching_test.rb` to cover language toggling behavior end-to-end, and updated existing tests to click the details-based account menu correctly.
- Conformed back-redirection and dashboard redirection in `LocalesController` and `WorkspacesController` to Turbo's 303 redirection behavior by adding `status: :see_other`.
- Updated UX design guidelines in `doc/design-input/ux/ux-guidelines.md` to establish rules for generous, full-area click targets across the application.


## [0.9.2] - 2026-06-06

### Security
- **Operator Notifications No Longer Reveal Document Titles:** Internal operator notifications for generated documents now show only the first six characters of the title followed by an ellipsis (e.g. `Begrüß...`), so the notification stream can’t disclose what a recording was about.

### Technical
- `RecordingSessionProcessor.redacted_title` produces the short preview, and the `nodl.document.generated` notification now carries a `redacted_title` in its payload — the full title never enters the event. Operator notification delivery (in `private/`) consumes that field instead of reading the title.


## [0.9.1] - 2026-06-06

### Fixed
- **Transcription Works in Production Again:** After recording and uploading, your audio now transcribes and turns into a document as expected. A server-side permissions problem that stopped processing with a “permission denied” error has been resolved.

### Technical
- Dockerfile pre-creates the processing scratch directory (`work/sessions`) with non-root ownership so `Nodl::WorkingDirectory` can write at runtime (fixes `Permission denied @ dir_s_mkdir - /rails/work`).
- `.dockerignore` selectively bakes `private/legal` and `private/initializers` into the production image (operator legal pages + telemetry initializer) while keeping secrets (`.env`) and heavy test fixtures out.
- Added `make deploy`: builds the `linux/amd64` image, pushes both `:<version>` and `:latest` to the private DockerHub registry, and triggers the Dokploy redeploy webhook (`DOKPLOY_DEPLOYMENT_HOOK`, read from `private/.env`).


## [0.9.0] - 2026-06-06

### Added
- **A Real Landing Page:** The home page now explains what Nodl does — speak a thought, get a structured document — with clear calls to start a free test, see pricing, and read FAQs. New visitors are greeted in English or German based on their browser language.
- **Free Test Limits You Can See Up Front:** The landing page and your dashboard now show the test-plan caps — up to 8 recordings, 5 formats, and 1 hour per recording — so you know what’s included before you sign up. The app enforces these limits and stops long recordings automatically.
- **Operator Legal Pages:** Imprint, privacy, and terms pages can be served from operator-specific content; footer links appear only when those pages are configured for your deployment.
- **A Friendlier “Page Not Found”:** In production, broken links show a branded 404 page instead of a generic error screen. (Developers still get full Rails debug pages locally.)

### Changed
- **Copy That Matches the Product:** Register, login, about, demo, and payments pages now describe Nodl as a voice-to-document tool with a free test tier and Pro coming soon — not generic Rails boilerplate text.
- **Clearer Account Menu:** The signed-in menu uses icons for workspace, language, upgrade, and sign-out so each action is easier to scan.
- **Nodl Brand Icons:** Browser tab and home-screen icons now use custom Nodl branding instead of the placeholder.

### Fixed
- **Readable Bottom Call-to-Action:** The final “start free” section on the landing page is legible again in light and dark mode.
- **Honest Limit Messages When Recording:** Hitting the recording cap now shows the real limit message instead of a misleading microphone error.

### Security
- **Edge Rate Limiting:** Added Rack::Attack throttles and blocklists for registration, login, junk probe paths, and a global request ceiling to harden the public deployment.

### Technical
- Added `PlanLimits` as the single source of truth for free-tier caps; enforced in models, processing, dashboard UI, and the browser recorder.
- Legal page wiring (`LegalPage`, routes, conditional footer links) with templates loaded from git-ignored `private/legal/`.
- Production routes exceptions to `ErrorsController`; development keeps `consider_all_requests_local` debug UI.
- Instrumented core product events via `ActiveSupport::Notifications` (`nodl.*`); operator Telegram delivery lives in `private/`.
- Added `config/initializers/rack_attack.rb` and `private_loader.rb` for operator initializers.


## [0.8.0] - 2026-06-06

### Security
- Patched the bundled Puma web server to resolve two High-severity CVEs.
- The production Docker image no longer ships the repo-private `private/` directory (nor `work/`, `test/`, or `doc/`), so local secrets and internal material can't end up in a built image.

### Technical
- Hardened database integrity ahead of launch: `transformer_profiles.instructions` is now `NOT NULL`, each recording can have only one generated document (enforced by a unique index plus a model validation), and redundant single-column indexes were dropped.
- Added a single `make check` handoff gate (migrations + lint + full test suite) and wired in `strong_migrations` (aborts unsafe migrations at `db:migrate`) and `database_consistency` (verifies model validations are backed by real DB constraints).
- Added opt-in SimpleCov coverage (`make coverage`) and re-enabled deliberately loose RuboCop complexity cops as regression guards.
- Fixed the `bin/brakeman` binstub, which was silently disabling the security scan; consolidated workspace nil-handling behind a shared `require_workspace!` controller guard.
- Routine dependency refresh: updated the OpenTelemetry suite and a batch of minor gems (`bootsnap`, `brakeman`, `jbuilder`, `mocha`, `propshaft`, `selenium-webdriver`, `solid_queue`, `thruster`, `web-console`, `kamal`).
- Added pre-launch code-quality audit documentation under `doc/design-output/code-quality/`.


## [0.7.0] - 2026-06-06

### Added
- **Use NODL in German:** The whole app is now available in German as well as English. Every page — the landing page, your dashboard, recordings, documents, formats, payments, and the admin area — along with buttons, messages, and notifications now appears in your chosen language.
- **Switch Languages Anytime:** A simple language switcher lets you pick between English and Deutsch. It's available right on the landing page before you sign in, and from the menu in the top-right corner once you're logged in. Languages are shown by name (English, Deutsch) — no flags.
- **Your Language Sticks:** When you're signed in, your language choice is saved to your account, so the app stays in your language across visits and devices. New visitors are greeted in their browser's language automatically when it's one we support.

### Technical
- Added Rails i18n with `en` (source of truth) and `de` locales: `config/locales/en.yml` and `de.yml` cover all UI strings, flash messages, and model validations; `de.yml` also carries hand-maintained German framework data (validation errors, date/time formats, relative time) so no extra gem is required.
- Locale is resolved per request in `ApplicationController` (session choice → user `preferred_language` → `Accept-Language` header → default) and persisted via a new `PATCH /locale/:locale` route and `LocalesController`.
- JavaScript-rendered copy (audio recorder status, processing progress labels, clipboard buttons) is localized by passing translations into Stimulus controllers through `data-*-value` attributes — no client-side i18n library needed.
- Added the `i18n-translate` skill plus a pure-Ruby delta script (`skills/i18n-translate/scripts/i18n_delta.rb`) to find untranslated keys, and `test/i18n/locale_parity_test.rb` to enforce that every locale defines the same application keys with matching interpolation placeholders.


## [0.6.0] - 2026-06-05

### Added
- **Copy Your Document with Formatting:** A new "Copy" button on the document page copies the whole document to your clipboard with its formatting intact — headings, bold text, and lists carry over cleanly when you paste into Word, Google Docs, email, or anywhere else.
- **Download Documents as PDF, Word, or Markdown:** A new "Download" menu on the document page lets you save your document as a PDF, a Microsoft Word file (.docx), or a Markdown file, so you can print it, share it, or keep editing it in your own tools.
- **Copy Your Transcript:** A "Copy" button on the recording page now copies the full transcript to your clipboard, with the speaker labels left out so you get clean, ready-to-paste text.

### Technical
- Added pure-Ruby export gems (`prawn`, `prawn-html`, `htmltoword`) — no native binaries — behind a new `DocumentExporters` service layer (`PdfExporter`, `DocxExporter`, `MarkdownExporter`) and a workspace-scoped `GET /documents/:id/download.:format` route. Both the PDF and Word exporters reuse the existing Markdown-to-HTML rendering pipeline.


## [0.5.0] - 2026-06-05

### Added
- **Smooth Audio-Duration-Based Progress Bar:** You can now see real-time progress of your recordings being processed on the dashboard, with a dynamic bar that estimates processing time using the audio duration and updates its status step-by-step ("Analyzing...", "Transcribing...", "Structuring...").
- **Accidental Recording Safeguard:** The "Record" button is now locked for 3 seconds immediately after you stop a recording to prevent accidental double-clicks or duplicate requests.
- **Voice-Reactive Live Panel Glow:** The live transcription box now blooms with a highly polished, voice-reactive outer halo and border light that expands and shines dynamically as you speak, providing clean and quiet visual feedback.
- **Polished Page Transitions:** Starting a new recording now automatically cleans up and resets the live transcription slot, while completing a recording triggers smooth collapse and grow animations to transition from the live panel to the new activity list row without sudden page jumps.

### Changed
- **Refined Navigation Flow:** Clicking a completed recording's title on the dashboard now takes you straight to the generated document. Jump back to its source session with the new "Show Recording" button on the document page, or find the session quickly using the "Open Recording" button in the activity list.

### Fixed
- **Support for Silence and Empty Audio:** Recordings with no detected speech are now resolved gracefully. NODL avoids calling external AI models with blank input (preventing errors and conversational filler) and returns a clean, deterministic "No speech detected" placeholder.

### Technical
- Implemented `estimated_duration` on `RecordingSession` to extract and compute the audio length in seconds from Active Storage blob metadata (via bitrate and byte size calculations) when not directly provided.
- Added native CSS keyframe animations for the collapsing live panel and expanding dashboard rows, as well as a custom-drawn CSS gradient text-shimmer for live transcripts.
- Added robust system-test coverage (`audio_recorder_js_test.rb`) to verify JavaScript-based button locking and animation states using Headless Chrome.


## [0.4.0] - 2026-06-05

### Added
- **Create Your Own Formats:** You can now create your own formats from the dashboard and tell NODL exactly how to turn a recording into the kind of document you need (for example meeting notes, a blog post, or a client summary). Each format has its own guidelines that NODL follows when writing your document.
- **Add Examples to Guide NODL:** When creating or editing a format, you can add up to 3 example documents so NODL matches your preferred structure and style. You can upload files, drag and drop them, or simply paste text straight into the form. Supported file types are Word (.docx), OpenDocument (.odt), PDF, Markdown (.md), and plain text (.txt).
- **Manage Your Formats:** View, edit, and delete your formats directly from the dashboard. The detail page shows a format's guidelines and the full content of its example documents, so you can see how a format works and use it as a starting point for your own.

### Changed
- **The "Basic Summary" Default Is Now Editable:** The built-in default format is now fully editable like any format you create — you can open it to read its guidelines and example, then tailor them to your needs. (The default can be edited but not deleted, so you always have one to fall back on.)

### Technical
- Custom format guidelines and example files are stored in the database (Active Storage), and example text is extracted on the fly using pure-Ruby parsers (`pdf-reader`, `docx`, `rubyzip` + Nokogiri) — no native binaries added to the image.
- The default transformer was moved off the filesystem into the database: the `source_path` column was dropped (with a backfill migration for existing default profiles), and `TransformerRepository` now resolves formats from the database for the web app and from the filesystem only for the CLI.


## [0.3.0] - 2026-06-05

### Security
- **Stronger Password Requirements:** Your account is now more secure with centralized password complexity validation requiring at least 8 characters, including uppercase, lowercase, and a number.
- **Fail-Closed Login Throttling:** Added a robust security guard that temporarily blocks login attempts if the background caching service is unavailable, preventing potential brute-force attacks.



### Changed
- **User-Friendly Naming Guidelines:** Added a comprehensive naming convention guide to ensure all product terminology remains clear, consistent, and accessible to non-technical users.


- **Simplified Dashboard UI:**
  - Redesigned the recording hub with a clean, left-aligned layout and stacked options for a more focused experience.
  - Positioned the "Record" and "Upload Audio" buttons side-by-side with a constrained width, giving the interface more breathing room on wide screens.
  - Replaced the live-preview status text with a clean spinner badge ("Finalizing…") and the transcript placeholder with a simple italic "Listening…".
  - Replaced the generic lock emoji in the privacy notice with a crisp, local Lucide lock icon.
- **User-Friendly Terminology:**
  - Replaced technical jargon with product-facing language across the entire interface: "Transformer" is now "Format", "Output types" is now "Formats", and "Transformation" is now "Generate document".
  - Renamed the default profile from "Default Transformer" to "Basic Summary" to make it more descriptive and intuitive.
- **Tightened Content Security Policy (CSP):** Restricted allowed script sources to prevent cross-site scripting (XSS) attacks, explicitly whitelisting only local scripts and Stripe.
- **Upgraded Core Dependencies:** Updated Rails and other third-party libraries to their latest secure versions (8.1.3), resolving all outstanding security vulnerabilities for a clean audit.

### Fixed
- **Session Title Truncation:** Fixed a layout overflow issue on the dashboard by truncating long recording session titles to a maximum of 45 characters, with a tooltip showing the full title on hover.


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
