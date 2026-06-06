
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
