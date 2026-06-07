# Nodl

> **A showcase of Agentic AI Engineering.** Nodl is a real, commercially-licensed product whose code is **100% AI-generated** — written by AI agents under human direction and held to production standards through automated quality gates, migration-safety checks, security scanning, and a full test suite. It is published source-available so the *engineering*, not just the product, can be inspected.

Nodl is a Ruby on Rails 8 SaaS application. It uses server-rendered ERB, Turbo, Stimulus, Tailwind CSS, DaisyUI, PostgreSQL, Rails-native session authentication, workspace-based tenancy, admin user management, and a Stripe Checkout placeholder flow. Built and maintained by ex-nihilo GmbH.

The local development workflow is Docker-only. You should not need a local Ruby, Rails, PostgreSQL, or Node runtime to boot and test the app.

## Engineering approach

Nodl demonstrates that agent-written code can meet a commercial quality bar when it runs through real engineering discipline:

- **100% AI-generated code**, authored by AI agents under human review and direction.
- **One handoff gate, always green:** `make check` runs migration-safety checks, linting, model↔DB constraint parity, and the full unit/integration/system suite before any change lands (see [Quality Gates](#quality-gates)).
- **Safety by default:** `strong_migrations` blocks unsafe migrations; `brakeman` and `bundler-audit` scan for vulnerabilities; security findings are tracked under `doc/design-output/security/`.
- **Decisions written down:** architecture, data models, module docs, and ADRs live under `doc/`.

## Stack

- Ruby on Rails 8.1
- PostgreSQL
- Tailwind CSS and DaisyUI
- Turbo and Stimulus
- Rails Minitest with Capybara system tests
- Stripe Ruby SDK for placeholder checkout/webhook flows
- OpenTelemetry instrumentation hooks

## Requirements

- Docker
- Docker Compose v2
- Make

The application image includes `ffmpeg`, which is required to normalize browser microphone recordings and non-MP3 uploads before transcription processing.

## Setup

Build the development image:

```sh
make build
```

Start the app and database:

```sh
make up
```

The application runs at:

```text
http://localhost:3000
```

Stop the stack:

```sh
make down
```

Optional: configure the repository-local git hooks:

```sh
make setup
```

For local environment overrides:

```sh
cp .env.example .env
```

The Docker `web` service loads `.env` and `private/.env` when present. Keep real secrets such as `GEMINI_API_KEY` and `MISTRAL_API_KEY` in one of those local files, preferably `private/.env` for repo-private values.

## Daily Commands

```sh
make build         # Build Docker images
make up            # Start the local stack in the background
make dev           # Alias for make up
make logs          # Stream Docker Compose logs
make shell         # Open a shell in the web container
make seed          # Seed demo data
make lint          # Run RuboCop + database_consistency inside Docker
make audit         # Scan gems for known CVEs (bundler-audit vs rubysec ruby-advisory-db)
make image-audit   # Trivy-scan a built image (OS packages + gems + secrets)
make test          # Prepare the test DB, then run Rails unit/integration and system tests
make check         # Handoff gate: db-check + lint + full tests (run before handing off work)
make check-fast    # Inner loop: db-check + lint + unit/integration tests (no system tests)
make db-check      # Apply migrations (runs strong_migrations) + assert db/schema.rb is in sync
make coverage      # Run tests with SimpleCov coverage; report to ./coverage/index.html
make down          # Stop and remove the local stack
```

## Database

The Docker Compose stack provisions PostgreSQL automatically. The Rails container runs `bin/rails db:prepare` before booting the development server.

Default local database names:

- `nodl_development`
- `nodl_test`

## Demo Seeds

Demo users are only created in development or when `ALLOW_DEMO_SEEDS=1` is set. Passwords are generated per seed run and printed once to stdout.

```sh
make seed
```

## Stripe Placeholder

The payment flow is intentionally placeholder-level. It provides a hosted Stripe Checkout redirect and webhook endpoint, but does not activate real subscriptions yet.

Supported routes:

- `GET /payments`
- `POST /payments/checkout`
- `GET /payments/success`
- `GET /payments/cancel`
- `POST /payments/webhook`

Environment variables:

```sh
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID=price_...
STRIPE_PRODUCT_NAME="Nodl Starter Plan"
STRIPE_DEFAULT_AMOUNT=1900
STRIPE_CURRENCY=usd
```

`STRIPE_PRICE_ID` is optional. Without it, the checkout flow creates inline `price_data` from `STRIPE_PRODUCT_NAME`, `STRIPE_DEFAULT_AMOUNT`, and `STRIPE_CURRENCY`.

## Audio Dashboard And Pipeline

Authenticated users can use `/dashboard` to create audio recording sessions, either by uploading an audio file or recording from the browser microphone. Browser recordings are stored as compact browser-native audio and normalized server-side with `ffmpeg` to MP3 for processing.

Each dashboard session stores:

- the original uploaded or recorded audio via Active Storage;
- a normalized MP3 copy when conversion is required;
- the generated transcript;
- structured transcript segments with timestamps and speaker labels when available;
- the generated Markdown document;
- the selected transformer handle.

Processing runs asynchronously through Active Job. Transcription uses Mistral Voxtral for both live preview and the authoritative batch pass. Document transformation still uses Gemini and filesystem transformer folders.

Dashboard processing requires `MISTRAL_API_KEY` and `GEMINI_API_KEY` in the Rails container environment. For local Docker development, set them in `.env` or `private/.env`, then restart the stack with `make down && make up`.

Supported upload/recording inputs include MP3 plus common browser/audio formats that `ffmpeg` can decode, such as WebM/Opus, MP4/AAC, OGG, AAC, FLAC, and WAV.

## Audio-To-Markdown CLI

The repository also includes a console entry point for turning an `.mp3` file into a Markdown document through Voxtral transcription and Gemini document transformation.

Run the full pipeline inside the Docker web container:

```sh
MISTRAL_API_KEY=... GEMINI_API_KEY=... docker compose exec -e MISTRAL_API_KEY -e GEMINI_API_KEY web bin/nodl run path/to/audio.mp3 --transformer default
```

`transcribe` is accepted as an alias for the same happy-path run:

```sh
MISTRAL_API_KEY=... GEMINI_API_KEY=... docker compose exec -e MISTRAL_API_KEY -e GEMINI_API_KEY web bin/nodl transcribe path/to/audio.mp3 --transformer default
```

Required environment:

```sh
GEMINI_API_KEY=...
MISTRAL_API_KEY=...
```

Optional model overrides:

```sh
NODL_VOXTRAL_MODEL=voxtral-mini-latest
NODL_VOXTRAL_REALTIME_MODEL=voxtral-mini-transcribe-realtime-2602
NODL_VOXTRAL_REALTIME_FAST_DELAY_MS=240
NODL_VOXTRAL_REALTIME_SLOW_DELAY_MS=2400
NODL_GEMINI_TRANSFORMER_MODEL=gemini-3.1-flash-lite
```

Transformers are local folders:

```text
transformers/
  default/
    instructions.md
    templates/
      example.md
```

Each run writes a session under `work/sessions/<run-id>/` containing `audio.mp3`, `transcript.md`, `transcript.segments.json`, `document.md`, and `metadata.json`. Dashboard processing stores the database records separately and keeps the generated `work/` directory ignored by git.

## Observability

OpenTelemetry export can be enabled with environment variables:

```sh
OTEL_SERVICE_NAME=nodl
OTEL_INGEST_TOKEN=...
OTEL_EXPORTER_OTLP_ENDPOINT=...
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=...
```

## Internationalization (i18n)

The app is **English-first** and ships with a complete German translation.

- Supported locales: `en` (source of truth) and `de`. Configured in `config/application.rb`.
- Translation files: `config/locales/en.yml` and `config/locales/de.yml`. German keeps common anglicisms (Dashboard, Login, Workspace, Checkout, Upload, Demo) and uses the informal "du".
- Locale resolution (`ApplicationController#switch_locale`): explicit session choice → signed-in user's `preferred_language` → `Accept-Language` header → default (`en`).
- Switching: a flag-free language switcher (globe icon + language endonyms) lives in the landing-page nav and in the signed-in user dropdown. It posts to `PATCH /locale/:locale`, persisting the choice in the session and on the user's account.
- JavaScript copy is localized by passing translated strings into Stimulus controllers via `data-*-value` attributes (no client-side i18n library needed).

Keeping translations in sync — find and fill the **delta** (keys present in `en` but missing from a target locale):

```sh
ruby skills/i18n-translate/scripts/i18n_delta.rb        # report all locales
ruby skills/i18n-translate/scripts/i18n_delta.rb de     # German only
ruby skills/i18n-translate/scripts/i18n_delta.rb --emit de  # YAML skeleton to translate
```

The `i18n-translate` skill (under `skills/`) guides an agent through translating the delta. `test/i18n/locale_parity_test.rb` enforces that every locale defines the same application keys with matching interpolation placeholders.

## Skills And Agents

Canonical skill sources live under `skills/`. Generated Claude/Codex outputs are local artifacts and are ignored by git.

```sh
make skills        # Generate local .claude/.codex skill outputs and sync AGENTS.md/CLAUDE.md
make skills-check  # Verify skill sources and agent instruction sync
make skills-clean  # Remove generated outputs
```

## Quality Gates

Before handing off significant changes, run the single handoff gate — it must pass:

```sh
make check        # db-check + lint + full tests (unit/integration + system)
```

For the inner development loop, a faster variant skips the browser/system tests:

```sh
make check-fast   # db-check + lint + unit/integration tests only
```

`make check` is the aggregate of three steps, each runnable on its own:

- `make db-check` — applies pending migrations (so [strong_migrations](https://github.com/ankane/strong_migrations) actually runs and aborts on unsafe operations) and asserts `db/schema.rb` is in sync (fails if a migration was added but not applied/committed).
- `make lint` — see below.
- `make test` — see below.

`make lint` runs, inside the container:

- `bin/rubocop` — style + a few loose complexity cops.
- `bundle exec database_consistency` — checks that model validations/associations are backed by DB constraints (FKs, NOT NULL, unique indexes). Pre-existing findings are baselined in `.database_consistency.todo.yml`; only *new* mismatches fail the check. Triage that baseline over time.

`make test` runs:

- `bin/rails test`
- `bin/rails test:system`

Migration safety is enforced by [strong_migrations](https://github.com/ankane/strong_migrations), which runs automatically during `bin/rails db:migrate` and aborts on unsafe operations. It fires wherever migrations actually run — `make up` (`db:prepare`) and `make db-check`. Note that `make test` uses `db:test:prepare` (a schema load), which does **not** run migrations, so `make db-check` is what exercises strong_migrations in the handoff gate. Existing migrations are grandfathered via `start_after` in `config/initializers/strong_migrations.rb`; checks target Postgres 16.

Optional JavaScript-specific system tests are guarded by environment flags where noted in the tests, for example `JS_SYSTEM_TESTS=1`.

### Dependency CVE scanning

```sh
make audit        # bundler-audit check against the rubysec ruby-advisory-db
```

`make audit` scans the locked gems for known vulnerabilities using [bundler-audit](https://github.com/rubysec/bundler-audit). It uses a single, reliable source — the community [rubysec/ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db) — which it clones/refreshes locally and matches against `Gemfile.lock`, so **no dependency data leaves your machine**.

It is intentionally **not** part of `make check`: it needs network to refresh the advisory DB, and a newly disclosed advisory can fail it without any code change on your side. Run it periodically and before a deploy. Suppress advisories that genuinely do not apply by adding them to the `ignore:` list in `config/bundler-audit.yml`.

`make audit` only sees declared gems (`Gemfile.lock`). To scan a **built image** — the OS layer (Debian packages such as `openssl`), the gems actually on disk, and leaked secrets — use [Trivy](https://github.com/aquasecurity/trivy):

```sh
make image-audit IMAGE=repo:tag             # styled HTML report (or just `make image-audit` to use DEPLOY_IMAGE from private/.env)
make image-audit IMAGE=repo:tag FORMAT=txt  # plain-text table instead
```

It runs Trivy as a container, downloads its vulnerability DB into a local cache volume (so nothing about the image leaves your machine), and reports HIGH/CRITICAL findings that have a fix available. Instead of flooding the terminal it writes a timestamped report to `tmp/security/image-audit-<timestamp>.{html,txt}` (git-ignored) and prints just a one-line summary and the path. `FORMAT=html` (default) is a styled report you can open in a browser and print to PDF; `FORMAT=txt` is a plain table. It is **informational** — it does not fail — and is kept separate from `make audit` because an image scan is only meaningful against a freshly built image. OS-layer findings are cleared by rebuilding the image (a fresh `apt-get` pulls patched packages); run it before a deploy.

### Test Coverage

Coverage is measured with SimpleCov and is **opt-in** (off by default so normal runs stay fast). Run it inside the container:

```sh
make coverage
```

This runs `COVERAGE=1 bin/rails test` in the `web` container and writes an HTML report to `./coverage/index.html` (git-ignored). The same opt-in works for ad-hoc runs:

```sh
docker compose exec -e COVERAGE=1 web bin/rails test
```

Treat the report as a map of untested paths, not a grade. System tests run in a separate process group and are not included in the figure, so real coverage of user-facing flows is higher.

## Documentation

Project documentation lives under `doc/`:

- `doc/index.md`
- `doc/design-input/` for user stories, domain notes, and exploratory design material.
- `doc/design-output/` for accepted architecture, API, data model, module, security, and ADR documentation.
- `doc/design-output/adr/`
- `doc/third-party/` for copied or curated third-party reference material.

## Security

Do not commit secrets. Local secrets such as `config/master.key`, `.env`, logs, temp files, and generated skill outputs are ignored by git.

The optional `private/` directory is ignored by git and reserved for a local/private companion repository.

See `SECURITY.md` for vulnerability reporting guidance and `CONTRIBUTING.md` for contribution expectations.

## License

Copyright (c) 2026 ex-nihilo GmbH.

Nodl is **source-available** under the [PolyForm Free Trial License 1.0.0](LICENSE). You may use it to **evaluate** whether it suits a particular application for **less than 32 consecutive days**, on behalf of you or your company. The Free Trial license does not permit production use, internal business use, redistribution, or any commercial use.

For any use beyond that free trial, obtain a **commercial license** from ex-nihilo GmbH. Contact ex-nihilo GmbH for commercial licensing terms.

Some non-code material uses separate terms or is reserved. See `LICENSES.md` for repository licensing boundaries.

The Nodl name, logo, and branding are trademarks or reserved marks of ex-nihilo GmbH and are not licensed under the PolyForm Free Trial License. See `TRADEMARKS.md`.

Third-party components retain their own licenses; see `LICENSES.md` and the `*-LICENSE` files alongside bundled assets (for example `app/assets/fonts/`).

<!-- BEGIN AGENT INSTRUCTIONS -->

# Agent Instructions

**IMPORTAN MUST FOLLOW** Explore your skills and agents in the .claude or .codex folder in the root of this repo.

## Orientation
- Use information from `README.md` for setup and daily commands.
- This project is a Rails 8 SaaS boilerplate (not FastAPI anymore). Prefer Rails conventions over custom frameworks.

## Stack Overview
- Backend: Ruby on Rails 8 (`app/controllers`, `app/models`, `app/views`), SSR with ERB.
- Database: PostgreSQL via Active Record migrations (`db/migrate`).
- Frontend: Tailwind CSS + DaisyUI, Turbo + Stimulus, minimal custom JavaScript.
- Auth: Rails-native session auth with `has_secure_password` (`User` model).
- Tenancy: multi-tenant domain via `Workspace` + `Membership`.
- Billing: Stripe placeholder flow in `PaymentsController`.
- Tests: Rails Minitest (unit/integration/system) with Capybara.
- Runtime: Docker Compose + Makefile workflow.

## Local Development
- Preferred commands (from repo root):
- `make build` build images.
- `make up` start stack in background.
- `make dev` alias for `make up`.
- `make logs` stream container logs.
- `make shell` open shell in web container.
- `make down` stop stack.
- App URL: `http://localhost:3000`.

## Quality Gates
- **Before handing off any work, run `make check` and it MUST pass (green).** This is the required handoff gate.
- `make check` runs, in order: `db-check` (applies migrations so `strong_migrations` runs + asserts `db/schema.rb` is in sync), `lint` (`rubocop` + `database_consistency`), then `test` (`bin/rails test` + `bin/rails test:system`).
- Use `make check-fast` (skips system tests) for the inner loop, but run the full `make check` before handoff.
- If you add a migration, `make db-check` will apply it and regenerate `db/schema.rb`; commit the updated schema. An unsafe migration aborts the gate — fix it (the error explains how) rather than bypassing it.
- Do not hand off with a red gate, and do not bypass it (no `--no-verify`, no skipping `make check`).
- Optional JS-specific system tests are guarded by env flags (example in README with `JS_SYSTEM_TESTS=1`).

## Coding Guidelines (Rails)
- Keep controllers thin; move business logic to models/service objects when complexity grows.
- Prefer RESTful routes and Rails helpers/path helpers.
- Use strong params, conventional validations, and Active Record associations.
- Favor server-rendered HTML responses with Turbo-compatible partial updates when needed.
- Keep JavaScript minimal; use Stimulus for small UI behaviors.
- Reuse DaisyUI components for visual consistency.
- Avoid introducing SPA patterns unless explicitly requested.

## Data & Migrations
- Schema changes must be done via Rails migrations in `db/migrate`.
- Keep `db/schema.rb` in sync with migrations.
- Use deterministic, reversible migrations where possible.
- Seed/demo data lives in `db/seeds.rb` and is run with `make seed`.

## Auth, Admin, and Tenancy
- Authentication flow: `register`, `login`, `logout` routes/controllers.
- Current tenant context is workspace-driven; keep tenancy boundaries explicit in queries and UI flows.
- Admin functionality lives under `Admin::` namespace (`/admin/users`), including audit events.

## Payments (Stripe Placeholder)
- User-facing flow routes:
- `/payments`
- `/payments/checkout`
- `/payments/success`
- `/payments/cancel`
- Webhook endpoint: `/payments/webhook`.
- Keep external Stripe calls stubbed in tests; do not require network access in CI/local tests.

## Security & Config
- Do not commit secrets. Use environment variables.
- Required/optional Stripe env vars are documented in `README.md`.
- Preserve CSRF/session behavior unless there is a clear, reviewed reason to modify it.
- The optional `private/` directory is ignored and reserved for a local/private companion repo; do not inspect, copy, modify, stage, or commit anything under it unless explicitly instructed by the user.

## Testing Guidance
- Add or update tests for behavior changes, especially in auth, tenancy, admin, and payments.
- Prefer fast, stable tests; avoid flaky browser-only tests when request/integration coverage is sufficient.
- For Stripe behavior, use integration tests with stubs/mocks (current setup uses `mocha` in test env).

## Git & Collaboration Rules
- Do not commit or rewrite history unless the user explicitly asks.
- Do not revert unrelated user changes.
- Keep diffs focused; update docs when behavior or developer workflow changes.

## Repository Hygiene
- Keep OS/editor artifacts out of git (`.DS_Store`, temp files, local caches).
- Keep `private/` out of the public repository. It may contain private test data, local deploy config, notes, or secrets managed outside the open-source repo.


## Quick Pointers
- Routes: `config/routes.rb`
- Main layout: `app/views/layouts/application.html.erb`
- Tailwind/DaisyUI theme config: `app/assets/tailwind/application.css`
- Tests: `test/`
- Dev commands: `Makefile`
<!-- END AGENT INSTRUCTIONS -->
