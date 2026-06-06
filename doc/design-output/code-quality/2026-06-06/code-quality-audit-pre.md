# Nodl — Pre-Launch Rails Audit

## 1. Executive Summary

This is a **clean, idiomatic, well-tested Rails 8 codebase** that a senior Rails developer would trust and could extend confidently. The quality is *deep, not surface-only*: tenant isolation is enforced consistently through `current_workspace`-scoped queries on every resource controller, and — critically — that isolation is **explicitly tested** with cross-tenant intrusion cases (`documents_download_test.rb:78`, `transformer_profiles_integration_test.rb:158`). Brakeman reports **0 warnings**, RuboCop is clean across 134 files, and the suite is 150 fast tests (641 assertions, 2.2s, 0 failures) with test LOC (3,304) exceeding app LOC (1,863). There is no over-engineering — controllers are skinny, business logic sits in a small number of justified service objects (`RecordingSessionProcessor`, document exporters), and the framework is trusted rather than wrapped.

The material problems are **operational, not architectural**, and all are pre-launch blockers rather than rewrites: (1) there is **no CI** — every quality gate is hope-based; (2) the bundled **Puma 7.2.0 has two High-severity CVEs**; (3) the production Docker image **bakes in the secret-bearing `private/` directory**; and (4) RuboCop here is a *formatter*, not a complexity gate (omakase disables all `Metrics/*` cops). None of these touch correctness; all are cheap to fix. Verdict: **ship-ready after a short, well-defined hardening pass.**

---

## 2. Findings

### 🔴 Bad / Needs improvement (lead with Risk)

**B1 — No CI pipeline; all quality gates are manual**
- **Evidence:** `.github/workflows` does not exist (`find .github` → nothing in the public repo; the only matches are under the ignored `private/external/freeflow`). The sole git hook is `.githooks/post-merge` (regenerates skills). `README`/`CLAUDE.md` document `make lint` / `make test` as "before handoff" rituals only.
- **Consequence (Changeability + Risk):** For an OSS project inviting outside PRs, nothing prevents a contributor (or you) from merging code that fails RuboCop, Brakeman, bundler-audit, or the test suite. The strong test discipline already in place is unenforced and will erode.
- **Recommendation:** Add a GitHub Actions workflow running on every push/PR: `bin/rubocop`, `bin/brakeman`, `bundle exec bundle-audit check --update`, `bin/rails db:test:prepare && bin/rails test test:system`. This is the single highest-leverage change. (See §4.)

**B2 — Bundled Puma has two High-severity CVEs** — ✅ **CLEARED (2026-06-06)**: `bundle update puma` → `8.0.2` in `Gemfile.lock`; `bundle-audit` now reports "No vulnerabilities found". (Restart the running container — `make down && make up` — so the live server picks up the new gem.)
- **Evidence:** `bundle-audit` → Puma `7.2.0`: `CVE-2026-47736` (PROXY protocol remote memory exhaustion, High) and `CVE-2026-47737` (PROXY header smuggling, High). Fix: `>= 8.0.2` (or `~> 7.2.1`). `Gemfile.lock` pins `puma (7.2.0)`; `Gemfile` only constrains `>= 5.0`.
- **Consequence (Risk):** Remote DoS / request-smuggling exposure on the public-facing server.
- **Recommendation:** `bundle update puma` to `>= 8.0.2`, re-run `bundle-audit`, commit the lockfile. Cheap.

**B3 — Production Docker image ships the secret-bearing `private/` directory** — ✅ **CLEARED (2026-06-06)**: `.dockerignore` now excludes `private`, `work`, `test`, `doc`. Dev (`Dockerfile.dev`) is unaffected because `docker-compose.yml` bind-mounts `.:/rails`, so `make test` still sees `test/`.
- **Evidence:** `.dockerignore` excludes `.env`, `config/master.key`, `log/`, `tmp/` — but **not `private/`** (nor `work/`, `doc/`, `test/`). `Dockerfile:48` is `COPY . .`; `Dockerfile:70` copies `/rails` into the final stage with no intervening cleanup. `private/` is, per `README`/`CLAUDE.md`, the reserved home for `private/.env`, deploy config, and a nested companion repo. Note `.env.*` in `.dockerignore` does **not** match `private/.env` (root-anchored glob).
- **Consequence (Risk):** Any published image (registry push, shared artifact) leaks whatever lives in `private/` — exactly the secrets it was created to keep out of the repo. The repo's careful git-ignoring of `private/` is undone at the image layer.
- **Recommendation:** Add `private/`, `work/`, `test/`, `doc/`, `.claude/`, `.codex/` to `.dockerignore`. Add a test or CI check asserting `private` is ignored by the build context. Quick win, high payoff.

**B4 — `bin/brakeman` binstub self-disables via `--ensure-latest`** — ✅ **CLEARED (2026-06-06)**: removed the `ARGV.unshift("--ensure-latest")` line from `bin/brakeman`; it now runs a real scan (verified: 12 controllers, 0 warnings).
- **Evidence:** `bin/brakeman` prepends `ARGV.unshift("--ensure-latest")`. Running it produced only `Brakeman 8.0.2 is not the latest version 8.0.4` and **exited without scanning** — the actual scan only ran via `bundle exec brakeman`.
- **Consequence (Risk + Changeability):** A CI step invoking `bin/brakeman` will break (false failure) the moment a newer Brakeman releases, regardless of code health — and locally it silently scans nothing, giving false assurance.
- **Recommendation:** Drop `--ensure-latest` from the binstub (or invoke `bundle exec brakeman` in CI and keep Brakeman version-pinned via Dependabot/`bundle update`).

### 🟡 Mid (acceptable, improvable)

**M1 — RuboCop is a formatter, not a complexity gate**
- **Evidence:** `.rubocop.yml` inherits `rubocop-rails-omakase`, which sets `Metrics/ClassLength`, `Metrics/MethodLength`, `Metrics/AbcSize`, etc. to `Enabled: false` (confirmed via `--show-cops`). The "0 offenses / 134 files" result reflects style only. `rubocop-performance` and `rubocop-rspec` are not loaded (the latter is correct — this is Minitest, not RSpec).
- **Consequence (Changeability):** Method/class bloat won't be caught automatically. Today it's fine (largest file `admin/users_controller.rb` at 287 LOC, mostly thin Turbo-stream render helpers), but nothing holds the line.
- **Recommendation:** Optionally enable a few loose Metrics thresholds (e.g. `Metrics/MethodLength: Max: 25`, `Metrics/ClassLength: Max: 250`) so regressions surface. Low priority given current state — don't over-tighten against omakase.

**M2 — Data migrations reference application models directly**
- **Evidence:** `20260605120000_rename_default_transformer_to_basic_summary.rb` and `20260605120003_backfill_default_transformer_profile_content.rb` call `TransformerProfile.where(...).update_all(...)` / model logic inside the migration.
- **Consequence (Changeability):** If `TransformerProfile` is later renamed or its validations change, replaying these old migrations on a fresh DB can break. (Mitigated in practice because new DBs use `schema.rb` load, not migration replay.)
- **Recommendation:** Acceptable as-is for a young project; for future data migrations prefer raw SQL or an inlined throwaway class. No action required now.

**M3 — `current_workspace` nil-safety is inconsistent across controllers** — ✅ **CLEARED (2026-06-06)**: added a shared `require_workspace!` in `ApplicationController`; wired as `before_action` in `DocumentsController` and `RecordingSessionsController` (dropping the inline nil-check in `#create`), and consolidated `TransformerProfilesController`'s duplicate local copy onto it. `DashboardController` keeps its intentional empty-state guard. Full suite still green (150 runs, 0 failures).
- **Evidence:** `DashboardController#show` guards `if @workspace`; `TransformerProfilesController` has `require_workspace!`. But `DocumentsController#show/#download` and `RecordingSessionsController#show/#finalize` call `current_workspace.documents…` / `current_workspace.recording_sessions…` with no nil guard (`documents_controller.rb:5`, `recording_sessions_controller.rb:29`).
- **Consequence (Risk: low):** A signed-in user with zero workspaces would hit `NoMethodError` → 500 instead of a clean redirect. Currently unreachable — registration and admin-create both always create a workspace+membership in a transaction — so this is latent, not live.
- **Recommendation:** Add a shared `before_action :require_workspace!` in `ApplicationController` (or a concern) for workspace-scoped controllers, mirroring the existing `authenticate_user!` pattern. Defends the invariant rather than relying on it.

**M4 — Coverage tooling absent; coverage is inferred, not measured**
- **Evidence:** No SimpleCov in `Gemfile`/`test`. Breadth is strong by inspection (models, 8 integration, 11 system via `rack_test`, 12 lib, 4 services, channel, i18n parity) but there is no untested-path map. Risky paths *are* covered (cross-tenant denial, login throttling, webhook signature, seed safety).
- **Consequence (Changeability):** Can't see which branches are unexercised; e.g. `RecordingSessionProcessor` failure/`ensure` cleanup paths and `estimated_duration` fallbacks aren't obviously covered.
- **Recommendation:** Add SimpleCov (dev/test) to produce a map — treat as a guide, not a grade.

### 🟢 Good (preserve these)

- **G1 — Tenant isolation is the default safe path and is tested.** Every resource controller queries through `current_workspace.<assoc>.find(...)`; cross-workspace access returns `404` by construction (`recording_sessions_controller.rb:29`, `documents_controller.rb:5,10`, `transformer_profiles_controller.rb:71`). ActionCable mirrors this — `connection.rb` identifies user+workspace and `live_transcription_channel.rb:12-15` rejects out-of-workspace sessions. Backed by explicit intrusion tests. This is the hardest thing to get right in multi-tenant SaaS and it's done correctly.
- **G2 — Mature authentication for a "boilerplate."** `SessionsController` implements login throttling keyed on SHA-256(email|IP), **fails *closed*** if the cache is unavailable (`CacheUnavailableError` → 503), uses `reset_session` on login/logout, and enforces password complexity centrally on `User`. Admin actions are fully audited via `AdminAuditEvent` with before/after JSONB state.
- **G3 — Solid DB integrity foundation.** `schema.rb` shows FKs on every association, `null: false` on all meaningful columns, unique indexes on `users.email`, `workspaces.slug`, `memberships [user_id, workspace_id]`, and a **partial unique index** enforcing one default transformer per workspace (`index_transformer_profiles_one_default_per_workspace`). Model validations are backed by DB constraints, not just app-layer hope.
- **G4 — Clean history & hygiene.** 103 commits, single author, feature-branch-and-merge flow, no edited migrations (each migration touched by exactly one commit), no secrets in history (`git log -p` over `*.env`/`master.key`/`credentials` is empty), and zero `binding.pry`/`puts`/`TODO`/`FIXME`/`console.log` in `app/`+`lib/`. `master.key` ignored, only encrypted `credentials.yml.enc` tracked.
- **G5 — Accurate cold-boot story.** `.ruby-version` (3.3.10) present, `.env.example` complete and consistent with README env tables, seeds properly guarded (`db/seeds.rb` refuses non-dev unless `ALLOW_DEMO_SEEDS=1`, prints per-run passwords once). README setup steps match reality. Production env is hardened: `force_ssl`, `assume_ssl`, `config.hosts` via `RAILS_ALLOWED_HOSTS`, health endpoints excluded from SSL redirect.

---

## 3. Quick Wins vs. Real Investment

**Quick wins (minutes to ~1 hour):** — ✅ all four done 2026-06-06
- [x] `bundle update puma` → clear B2 (both CVEs).
- [x] Add `private/`, `work/`, `test/`, `doc/` to `.dockerignore` → clear B3.
- [x] Remove `--ensure-latest` from `bin/brakeman` → clear B4.
- [x] Add `before_action :require_workspace!` for workspace-scoped controllers → clear M3.

**Real investment (half-day to a day):**
- Stand up the GitHub Actions CI pipeline with hard gates (B1) — the structural fix that makes all the above stay fixed.
- Add SimpleCov + optional loose Metrics cops (M1, M4).
- Run the tools I could not run locally (not in Gemfile): wire `strong_migrations` and `database_consistency` as ongoing checks.

---

## 4. Enforcement Recommendations

**CI (`.github/workflows/ci.yml`, on `push` + `pull_request`) — make these hard, blocking jobs:**
```
bin/rubocop
bundle exec brakeman --no-pager        # not bin/brakeman (B4)
bundle exec bundle-audit check --update # fails build on vulnerable gems
bin/rails db:test:prepare && bin/rails test test:system
```
System tests already use `driven_by :rack_test` (`test/application_system_test_case.rb:4`), so CI needs **no browser** — they run headless. Keep the `JS_SYSTEM_TESTS` ones opt-in.

**Dependency hygiene:** enable Dependabot (or Renovate) for `bundler` weekly — this keeps Puma/net-ssh/rubocop-rails current and prevents the next B2.

**RuboCop:** keep omakase; optionally append loose guards so complexity regressions surface without fighting the style baseline:
```yaml
Metrics/MethodLength: { Max: 25 }
Metrics/ClassLength:  { Max: 250 }
Metrics/AbcSize:      { Max: 30 }
```

**Local pre-push hook** (mirror CI cheaply): `git config core.hooksPath .githooks` already exists via `make setup`; add a `pre-push` that runs `bin/rubocop` + `bin/rails test` so failures are caught before they reach a PR.

---

### Tools I could NOT run (and exact commands to enable them)
Not in the Gemfile, so not executed — add to `group :development, :test` and run:
- **strong_migrations** — `gem "strong_migrations"`; then catches unsafe migrations at definition time.
- **database_consistency** — `gem "database_consistency", require: false`; run `bundle exec database_consistency` to verify validations↔DB-constraints parity (your parity is already good by inspection, but this enforces it).
- **rubycritic** — `gem "rubycritic", require: false`; `bundle exec rubycritic app lib` for churn-vs-complexity (manual, not a CI gate).
- **SimpleCov** — `gem "simplecov", require: false` in `:test`, `SimpleCov.start "rails"` at top of `test_helper.rb`.

Everything else in the requested sweep was run inside the `web` container: RuboCop (clean), Brakeman (0 warnings, via `bundle exec`), bundler-audit (2 High Puma CVEs), `bundle outdated` (puma, net-ssh, rubocop-rails, opentelemetry-instrumentation-rack), and the full test suite (150/0/0).