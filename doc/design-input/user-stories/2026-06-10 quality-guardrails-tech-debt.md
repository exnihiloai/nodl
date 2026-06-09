# Tech Debt: Quality Guardrails and Drift Removal

As a Nodl maintainer,
I want small executable quality guards and the removal of known duplication and parked debt,
so that silent failure modes and drift do not accumulate while the team is small.

## Scope

### 1. JS system tests in CI
The JS-gated system tests (`JS_SYSTEM_TESTS=1`) cover the microphone recorder —
the core product loop — but do not run in CI today. They should run on the
self-hosted runner, specifically in the MR pipeline.

### 2. Validate recurring jobs configuration
A typo in a `class:` or `command:` entry in `config/recurring.yml` fails
silently at runtime in production. Add an executable check (per the "Enforce
Invariants with Checks, not Conventions" principle in AGENTS.md) that every
recurring entry resolves — class names constantize, commands parse.

### 3. Single source for constants shared by CLI and web pipeline
`DEFAULT_TRANSCRIBER_MODEL` is defined twice
(`app/services/recording_session_processor.rb`, `lib/nodl/cli.rb`). Audit the
CLI/web split for duplicated constants and configuration and consolidate each
to one definition point.

### 4. One-command dev reset
Resetting local development to a clean seeded state is currently a manual
multi-step (clear storage, reload schema, seed). Provide a `make reset-dev`
target and document it in the Makefile help.

### 5. Burn down the database_consistency todo file
`.database_consistency.todo.yml` parks known model/DB-constraint mismatches
without context. Resolve each entry, or annotate it with a dated reason why it
stays parked.

## Acceptance Criteria

- CI executes the JS system tests (MR pipeline or scheduled) and fails on regressions.
- A broken `recurring.yml` entry fails `make check` with a message naming the bad entry.
- Constants shared between CLI and web have exactly one definition; tests still pass.
- `make reset-dev` exists, works from a dirty dev state, and appears in `make help`.
- `.database_consistency.todo.yml` is empty or every entry carries a dated rationale.

## Out of Scope

- Backup automation for production (separate decision; see ops runbook).
- AGENTS.md/CLAUDE.md generation/sync tooling.
- Test-coverage thresholds or new tooling beyond the checks named above.
