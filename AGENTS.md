
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


## Quick Pointers
- Routes: `config/routes.rb`
- Main layout: `app/views/layouts/application.html.erb`
- Tailwind/DaisyUI theme config: `app/assets/tailwind/application.css`
- Tests: `test/`
- Dev commands: `Makefile`

## AI Collaboration Workflow

- **Rule 1 – Plan before coding:** Before writing any code, state the planned approach in 2–5 bullet points. Do not proceed until the user explicitly approves. If the requirement is ambiguous, ask one focused clarifying question.
- **Rule 2 – Scope gate:** If a task touches more than 3 files, stop. List the affected files, propose atomic sub-steps, and ask which step to start with.
- **Rule 3 – Impact summary:** After completing a task, output a brief "What could break" list and specify which `make test` / `bin/rails test` commands cover those areas.
- **Rule 4 – Red-Green bug fixing:** For any bug: (1) write a failing test that reproduces it, (2) confirm it fails with `make test`, (3) fix the code, (4) confirm it passes. Never skip to step 3.
- **Rule 5 – Self-updating rules:** After any user correction, add a new, specific rule to `README.md` under `## AI Collaboration Workflow` between the marker for begin and end of the `AGENTS INSTRUCTIONS` section. The rule must name the exact mistake class, not just repeat general advice.
- **Rule 6 – Critical architecture stop:** If a change touches authentication flow, `current_workspace` resolution, session handling, billing logic, role/permission logic, or data-impacting migrations: stop after planning, list risks, and wait for explicit user approval before coding.
- **Rule 7 – No opportunistic refactors:** Do not refactor unrelated code, rename unrelated methods, or move files unless explicitly requested. Change only what the task requires.
- **Rule 8 – Security integrity:** Never disable CSRF, skip authentication/authorization filters, permit-all params, or bypass authorization unless explicitly instructed by the user.
- **Rule 9 – Migration safety:** Do not remove columns without a deprecation step, do not perform non-reversible data-impacting migration changes, always plan backfills when needed, and confirm `db/schema.rb` is updated.
- **Rule 10 – Agent permissions:** When spawning the `documentation_architect` or `documentation_auditor` agent (or any agent that must write files to the repo), always use `mode: "bypassPermissions"` or `dangerouslySkipPermissions` in the Task tool call. Without this, the agent will stall waiting for Write/Bash permission and produce no output.
- **Rule 11 – Compact story outputs:** If the user requests concise user stories, enforce a hard `<= 3000` character limit and exclude implementation and tech-stack guidance unless explicitly requested.
