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
make reset-dev     # Reset local dev to a clean seeded state (wipes DB data, uploads, work sessions)
make lint          # Run RuboCop + database_consistency inside Docker
make audit         # Scan gems for known CVEs (bundler-audit vs rubysec ruby-advisory-db)
make image-audit   # Trivy-scan a built image (OS packages + gems + secrets)
make test          # Prepare the test DB, then run Rails unit/integration and system tests (incl. browser JS)
make test-js       # Run only the system tests (incl. browser JS via headless Chromium)
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

## Features

Feature details live with the module documentation under `doc/design-output/`:

- **Audio dashboard & pipeline** — authenticated `/dashboard` for uploading or recording audio, normalized with `ffmpeg` and turned into a Markdown document via Voxtral transcription + Gemini transformation. Requires `MISTRAL_API_KEY` and `GEMINI_API_KEY` in the container environment (set them in `.env` or `private/.env`). See [dashboard.md](doc/design-output/modules/dashboard.md) and [audio-pipeline.md](doc/design-output/modules/audio-pipeline.md).
- **Audio-to-Markdown CLI** — the same pipeline from a console entry point (`bin/nodl run …`). See [audio-pipeline.md](doc/design-output/modules/audio-pipeline.md).
- **Tamper-evident audio archiving** — optional per-user integrity sealing with SHA-256 + RFC 3161 trusted timestamps and a downloadable proof ZIP. See [tamper-evident-audio-archiving.md](doc/design-output/modules/tamper-evident-audio-archiving.md).
- **Stripe checkout (placeholder)** — hosted Checkout redirect and webhook endpoint, not yet activating real subscriptions. See [payments.md](doc/design-output/modules/payments.md).
- **Internationalization** — English-first with a complete German translation. See [i18n.md](doc/design-output/modules/i18n.md).

OpenTelemetry export can be enabled via `OTEL_*` environment variables (`OTEL_SERVICE_NAME`, `OTEL_INGEST_TOKEN`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`).

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
make check-fast   # inner loop: db-check + lint + unit/integration tests only (no system tests)
```

`make check` aggregates `make db-check` (migration safety via [strong_migrations](https://github.com/ankane/strong_migrations) + schema sync), `make lint` (RuboCop + `database_consistency`), and `make test` (Rails unit/integration + JS system tests). Separate, independently runnable checks cover dependency CVE scanning (`make audit`, `make image-audit`) and coverage (`make coverage`).

See [doc/design-output/quality-gates.md](doc/design-output/quality-gates.md) for the full breakdown of each step and security scan.

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
