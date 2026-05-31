# Nodl

Nodl is a Ruby on Rails 8 SaaS starter application. It uses server-rendered ERB, Turbo, Stimulus, Tailwind CSS, DaisyUI, PostgreSQL, Rails-native session authentication, workspace-based tenancy, admin user management, and a Stripe Checkout placeholder flow.

The local development workflow is Docker-only. You should not need a local Ruby, Rails, PostgreSQL, or Node runtime to boot and test the app.

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

## Daily Commands

```sh
make build         # Build Docker images
make up            # Start the local stack in the background
make dev           # Alias for make up
make logs          # Stream Docker Compose logs
make shell         # Open a shell in the web container
make seed          # Seed demo data
make lint          # Run RuboCop inside Docker
make test          # Prepare the test DB, then run Rails unit/integration and system tests
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

## Audio-To-Markdown Prototype

The repository includes a console-only prototype for turning an `.mp3` file into a Markdown document through Gemini. It is intentionally filesystem-based and does not use the database or a UI yet.

Run the full pipeline inside the Docker web container:

```sh
GEMINI_API_KEY=... docker compose exec -e GEMINI_API_KEY web bin/nodl run path/to/audio.mp3 --transformer default
```

`transcribe` is accepted as an alias for the same happy-path run:

```sh
GEMINI_API_KEY=... docker compose exec -e GEMINI_API_KEY web bin/nodl transcribe path/to/audio.mp3 --transformer default
```

Required environment:

```sh
GEMINI_API_KEY=...
```

Optional model overrides:

```sh
NODL_GEMINI_TRANSCRIBER_MODEL=gemini-3.1-flash-lite
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

Each run writes a session under `work/sessions/<run-id>/` containing `audio.mp3`, `transcript.md`, `document.md`, and `metadata.json`. The generated `work/` directory is ignored by git.

## Observability

OpenTelemetry export can be enabled with environment variables:

```sh
OTEL_SERVICE_NAME=nodl
OTEL_INGEST_TOKEN=...
OTEL_EXPORTER_OTLP_ENDPOINT=...
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=...
```

## Skills And Agents

Canonical skill sources live under `skills/`. Generated Claude/Codex outputs are local artifacts and are ignored by git.

```sh
make skills        # Generate local .claude/.codex skill outputs and sync AGENTS.md/CLAUDE.md
make skills-check  # Verify skill sources and agent instruction sync
make skills-clean  # Remove generated outputs
```

## Quality Gates

Before handing off significant changes:

```sh
make lint
make test
```

`make test` runs:

- `bin/rails test`
- `bin/rails test:system`

Optional JavaScript-specific system tests are guarded by environment flags where noted in the tests, for example `JS_SYSTEM_TESTS=1`.

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

Nodl is licensed under the GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`). See `LICENSE`.

Commercial or proprietary licenses may be granted separately by ex-nihilo GmbH. Contact ex-nihilo GmbH for dual licensing terms.

Some non-code material may use separate terms or be reserved. See `LICENSES.md` for repository licensing boundaries.

The Nodl name, logo, and branding are trademarks or reserved marks of ex-nihilo GmbH and are not licensed under the AGPL. See `TRADEMARKS.md`.

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
- Run lint before handing off significant changes: `make lint`.
- Run tests before handing off significant changes: `make test`.
- `make test` runs both `bin/rails test` and `bin/rails test:system`.
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
