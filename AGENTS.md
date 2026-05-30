# Agent Instructions

## Core Rule

**IMPORTANT MUST FOLLOW:** Explore repo-local agent instructions, skills, commands, and subagents in `.claude/` and `.codex/` at the root of this repo before significant work.

Agents should be autonomous by default when the requirement is clear and risk is low. Do not stop at a proposal unless the user explicitly asked for planning only, or the change falls under a required human-approval area.

## Orientation

Before touching code:

- Read `README.md` for setup, architecture, and daily commands.
- Inspect relevant files under `doc/` when present.
- Inspect `.claude/` and `.codex/` for repo-local agent workflows, skills, commands, or subagents.
- Use existing code structure and conventions as the source of truth.
- This project is a Rails 8 SaaS boilerplate. Prefer Rails conventions over custom frameworks.

## Stack Overview

- Backend: Ruby on Rails 8 (`app/controllers`, `app/models`, `app/views`), SSR with ERB.
- Database: PostgreSQL via Active Record migrations (`db/migrate`).
- Frontend: Tailwind CSS + DaisyUI, Turbo + Stimulus, minimal custom JavaScript.
- Auth: Rails-native session auth with `has_secure_password` (`User` model).
- Tenancy: multi-tenant domain via `Workspace` + `Membership`.
- Billing: Stripe placeholder flow in `PaymentsController`.
- Tests: Rails Minitest unit/integration/system tests with Capybara.
- Runtime: Docker Compose + Makefile workflow.

## Local Development

Preferred commands from repo root:

- `make build` builds images.
- `make up` starts the stack in the background.
- `make dev` aliases `make up`.
- `make logs` streams container logs.
- `make shell` opens a shell in the web container.
- `make down` stops the stack.
- `make seed` loads seed/demo data.
- App URL: `http://localhost:3000`.

## Definition of Done

A task is not done until all applicable items below are complete:

- The requested behavior is implemented.
- New or changed behavior has meaningful test coverage.
- Bug fixes include a regression test that fails before the fix, unless the user explicitly waives this or the bug is impossible to test at the current layer.
- The smallest relevant targeted test has been run during iteration.
- The full test suite has been run with `make test` before final handoff.
- `make lint` has been run before final handoff for code changes.
- All required tests and lint checks pass.
- If frontend behavior changed, relevant system tests or browser verification have been run.
- If any required check cannot be run or does not pass, the agent must not say the task is done. It must report the blocker, summarize the relevant output, and state what remains.

## AI Collaboration Workflow

### Operating Model

- Prefer acting over asking when the requirement is clear and risk is low.
- Ask one focused clarifying question only when the missing answer would materially change implementation, data behavior, security, billing, or user-facing behavior.
- Do not hand back after only planning unless the user asked for a plan only.
- Keep working through implementation, verification, and a clear final summary whenever feasible.
- Do not commit or rewrite git history unless the user explicitly asks.

### Planning Before Work

- For trivial or narrow changes, proceed directly after briefly stating what you are inspecting or changing.
- For non-trivial work, state a concise 2-5 bullet plan before editing.
- Wait for explicit user approval before coding only when the change touches:
  - authentication flow;
  - session handling;
  - `current_workspace` or tenant resolution;
  - billing or Stripe behavior;
  - role or permission logic;
  - data-impacting migrations;
  - production deployment;
  - irreversible or destructive operations.

### Implementation Rules

- Keep diffs focused on the requested change.
- Follow Rails conventions before adding custom structure.
- Keep controllers thin; move business logic to models, concerns, or service objects when complexity justifies it.
- Prefer RESTful routes and Rails path helpers.
- Use strong params, conventional validations, and Active Record associations.
- Favor server-rendered ERB, Turbo-compatible partial updates, Stimulus, Tailwind, and DaisyUI.
- Keep JavaScript minimal.
- Avoid SPA patterns unless explicitly requested.
- Do not opportunistically refactor unrelated code.
- Do not rename unrelated methods or move unrelated files.
- Do not revert unrelated user changes.

## Testing Requirements

- Agents must add or update tests for every behavior change.
- For bug fixes, agents must first create or update a failing regression test, run the smallest relevant test to confirm it fails, then implement the fix.
- Use targeted tests for iteration.
- Always run `make test` before final handoff.
- Do not replace the final `make test` gate with targeted tests.
- Run `make lint` before final handoff for code changes.
- If frontend behavior changed, run the relevant system test or browser verification in addition to `make test`.
- Never claim completion when tests are failing, skipped without explanation, or not run.

## Quality Gates

- `make lint` is required before handing off significant code changes.
- `make test` is required before handing off behavior changes.
- `make test` runs both `bin/rails test` and `bin/rails test:system`.
- Optional JS-specific system tests may be guarded by env flags such as `JS_SYSTEM_TESTS=1`; use them when the change affects that behavior.
- If a full test run cannot be completed, explain exactly why and list what was run instead.

## Bug Fix Workflow

For any bug fix:

1. Add or update a regression test that reproduces the bug, unless impossible or explicitly waived.
2. Run the smallest relevant test command to confirm the test fails.
3. Fix the code.
4. Re-run the targeted test and confirm it passes.
5. Run `make test`.
6. Run `make lint` for code changes.
7. Do not mark the task done unless all required checks pass.

## Handoff Rules

Hand back to the human when:

- the task is implemented and verified;
- a product ambiguity cannot be safely inferred;
- credentials, secrets, external accounts, or deployment access are required;
- a critical architecture area requires approval;
- unrelated existing failures block the final quality gate;
- the user explicitly asks to pause or only provide a plan.

Final handoff must include:

- what changed;
- tests and lint commands run;
- whether all checks passed;
- a brief "What could break" list;
- any known gaps, blockers, or follow-up needed.

## Coding Guidelines Rails

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
- Do not remove columns without a deprecation or contract step.
- Do not perform non-reversible data-impacting migration changes unless explicitly approved.
- Plan backfills when needed.
- Call out migration risks before coding if production data may be affected.

## Auth, Admin, and Tenancy

- Authentication flow: `register`, `login`, `logout` routes/controllers.
- Current tenant context is workspace-driven; keep tenancy boundaries explicit in queries and UI flows.
- Admin functionality lives under the `Admin::` namespace, including `/admin/users` and audit events.
- Changes to auth, tenant resolution, sessions, roles, permissions, or admin access require a plan and explicit user approval before coding.

## Payments Stripe Placeholder

- User-facing flow routes:
  - `/payments`
  - `/payments/checkout`
  - `/payments/success`
  - `/payments/cancel`
- Webhook endpoint: `/payments/webhook`.
- Keep external Stripe calls stubbed in tests.
- Do not require network access in CI or local tests.
- Changes to billing or Stripe behavior require a plan and explicit user approval before coding.

## Security & Config

- Do not commit secrets. Use environment variables.
- Required and optional Stripe env vars are documented in `README.md`.
- Preserve CSRF/session behavior unless there is a clear, reviewed reason to modify it.
- For git operations treat `private/` as ignored local/private companion-repo. Never commit anything in that folder.
- Never disable CSRF, authentication, authorization, tenant scoping, or strong params protections unless explicitly instructed by the user and the risk is documented.
- Never permit all params or bypass authorization as a shortcut.

## Testing Guidance

- Add or update tests for behavior changes, especially in auth, tenancy, admin, and payments.
- Prefer fast, stable tests; avoid flaky browser-only tests when request/integration coverage is sufficient.
- For Stripe behavior, use integration tests with stubs/mocks. The current setup uses `mocha` in test env.
- Keep tests deterministic.
- Do not require live network access for tests.

## Git & Collaboration Rules

- Do not commit unless the user explicitly asks.
- Do not rewrite history unless the user explicitly asks.
- Do not revert unrelated user changes.
- Keep diffs focused.
- Update docs when behavior, setup, commands, or developer workflow changes.
- If the worktree contains unrelated changes, leave them alone.

## Documentation Updates

- Update documentation when behavior, setup, commands, or workflows change.
- After a user correction, add or propose a specific durable rule only when the correction reflects a recurring project preference.
- New rules should name the exact mistake class they prevent, not repeat generic advice.
- Do not mutate docs merely to record one-off preferences unless asked.

## Repository Hygiene

- Keep OS/editor artifacts out of git, including `.DS_Store`, temp files, and local caches.
- Keep `private/` out of the public repository. It is reserved for private test data, local deployment config, notes, or other non-public companion files.
- Remove unused code and artifacts introduced by the task.
- Do not add dependencies unless they are necessary and justified.

## Quick Pointers

- Routes: `config/routes.rb`
- Main layout: `app/views/layouts/application.html.erb`
- Tailwind/DaisyUI theme config: `app/assets/tailwind/application.css`
- Tests: `test/`
- Dev commands: `Makefile`

## Agent And Subagent Permissions

- If this repo defines Claude/Codex subagents or local automation under `.claude/` or `.codex/`, inspect their instructions before use.
- When spawning a subagent that must write files or run commands, ensure it has the required permissions according to that tool's local workflow.
- If a subagent stalls because it lacks write or shell permissions, stop using that subagent and continue directly or report the blocker.

## Compact Story Outputs

- If the user requests concise user stories, enforce a hard `<= 3000` character limit.
- Exclude implementation and tech-stack guidance from concise user stories unless explicitly requested.
