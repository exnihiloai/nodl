# Audit: Nodl Rails 8 SaaS — Pre-OSS-Launch Review

## 1. Executive Summary

**Verdict: This is a genuinely clean, idiomatic Rails 8 codebase that a senior Rails developer would trust and could extend safely next week.** The quality is *deep, not surface-only* — tenant isolation holds at every layer I probed (controllers, the Action Cable channel, and the connection), automated scanners come back clean, and the test suite (150 runs, 641 assertions, 0 failures/skips, 2.3s) actually covers the risky paths: tenancy, payments, and the live-transcription channel.

Five material points:
1. **Tenant isolation is safe-by-default.** Every `find(params[:id])` is scoped through `current_workspace`; the one exception (`User.find` in `Admin::UsersController`) is correctly global, and the background job loads by trusted internal ID. No unscoped finds, no raw SQL, no string interpolation into queries anywhere in `app/`.
2. **Auth is careful, not cargo-cult.** bcrypt via `has_secure_password`, `reset_session` on login, login throttling that *fails closed* on cache errors, and an `active?` check enforced on **both** session login and the cable connection.
3. **The biggest gap is enforcement, not code:** there is **no CI**. The `make check` handoff gate is excellent but honor-system only — the sole git hook is `post-merge` (skills regen). For a public repo accepting contributor PRs, quality is currently *hoped for*, not *enforced*.
4. **DB integrity foundations are in place:** FKs, NOT NULL, and unique indexes exist; the most recent NOT-NULL migration uses the textbook `strong_migrations` safe pattern; `strong_migrations` + `database_consistency` are both wired into the gate.
5. **No over-engineering.** Models are thin (largest is 182 lines), services exist only where they earn their keep (audio processing, document export), and there are zero needless repositories/interactors/DI layers. Framework trust throughout.

The codebase reads as one consistent era of work (single author, 103 commits, branch-and-merge workflow, no edited migrations, no secrets in HEAD or history). Hygiene is impeccable: **zero** TODO/FIXME, `binding.pry`, `console.log`, or `rubocop:disable` across `app/` and `lib/`.

---

## 2. Findings

### Bad / Needs Improvement (lead with Risk)

#### B1. No CI — the quality gate is unenforced
- **Evidence:** No `.github/workflows/` exists (`ls` → "No such file or directory"; the only workflows found are under git-ignored `private/external/freeflow/`). `make setup` runs `git config core.hooksPath .githooks`, but `.githooks/` contains only `post-merge` (skills regeneration). No pre-commit/pre-push hook runs `make check`.
- **Consequence (Risk + Changeability):** For an OSS launch, contributor PRs and your own pushes can land red. A tenant-isolation regression, an unsafe migration, or a failing test would not be caught automatically — the entire safety net (`strong_migrations`, RuboCop, `database_consistency`, 150 tests) depends on a human remembering to run it. This is the single highest-leverage gap.
- **Recommendation:** Add a GitHub Actions workflow on `push`/`pull_request` that reproduces `make check` (Postgres service container, `db:migrate` so `strong_migrations` fires, `bin/rubocop`, `database_consistency`, `bin/rails test` + `test:system`). Make it a required status check on `main`.

#### B2. `recording_sessions ⇄ documents` one-to-one has no DB-level uniqueness
- **Evidence:** `RecordingSession has_one :document` (`app/models/recording_session.rb:20`), but `db/schema.rb:67` shows only a plain `index_documents_on_recording_session_id`, not a unique one. `database_consistency` flags this (`MissingIndexChecker fail RecordingSession document … should have a unique index`), currently baselined in `.database_consistency.todo.yml:13`.
- **Consequence (Risk — data integrity):** Nothing at the database level prevents two `documents` rows pointing at one recording session. Today the app is safe because `mark_completed!` wraps `document&.destroy!` + `create_document!` in a transaction (`recording_session.rb:62`), but that's an application-level guarantee a future code path (or a retried job racing) could violate, leaving the `has_one` to silently return an arbitrary row.
- **Recommendation:** Add a unique index on `documents.recording_session_id` (safe pattern: `add_index … unique: true, algorithm: :concurrently`), then remove the baseline entry. Low effort, closes the gap permanently.
- ✅ **CLEARED (2026-06-06):** migration `20260606130000_add_unique_index_to_documents_recording_session.rb` replaces the plain index with a `unique`, `algorithm: :concurrently` one (strong_migrations did not abort). Backed the DB constraint with `validates :recording_session_id, uniqueness: true` in `Document` so `database_consistency`'s `UniqueIndexChecker` is satisfied without a baseline. Baseline entry removed; suite green (150 runs, 0 failures).

### Mid (acceptable but improvable)

#### M1. `database_consistency` baseline risks becoming a graveyard
- **Evidence:** `.database_consistency.todo.yml` carries 8 suppressed findings — 5 redundant single-column indexes (e.g. `index_memberships_on_user_id` covered by the composite), the B2 missing unique index, a unique-index-without-validator on `index_transformer_profiles_one_default_per_workspace` (a model validation *does* exist, `transformer_profile.rb:80`, so this one is benign), and a `User.password_digest` null-validator note (benign — `has_secure_password` enforces it).
- **Consequence (Changeability):** Baselines are healthy *only if triaged down*. The redundant indexes are minor write-amplification/bloat; left indefinitely the file teaches future contributors that suppression is the norm.
- **Recommendation:** Drop the 5 redundant indexes in one migration, fix B2, and aim to empty the file. The two benign entries can stay with a one-line comment explaining why.
- ✅ **CLEARED (2026-06-06):** migration `20260606130100_drop_redundant_single_column_indexes.rb` drops the 4 remaining redundant single-column indexes concurrently (`documents.workspace_id`, `memberships.user_id`, `recording_sessions.workspace_id`, `transformer_profiles.workspace_id`); the 5th, `documents.recording_session_id`, was converted to unique in B2 rather than dropped. `.database_consistency.todo.yml` now holds only the two benign entries (transformer `one_default_per_workspace`, `User.password_digest`), each documented with a one-line comment. `database_consistency` run is clean (no failures).

#### M2. Data-backfill migration couples to live model constants
- **Evidence:** `db/migrate/20260605120003_backfill_default_transformer_profile_content.rb` calls `TransformerProfile.update!` and reads `TransformerProfile::DEFAULT_INSTRUCTIONS` / `DEFAULT_EXAMPLE_CONTENT`.
- **Consequence (Changeability):** A historical migration now depends on current model code and Active Storage. If those constants/validations later change or are removed, replaying the migration on a fresh DB can break — the classic "migrations should be self-contained" trap.
- **Recommendation:** Acceptable for a one-time backfill that has already run everywhere, but for new backfills inline the literal content (or use `execute`/raw SQL) so the migration is frozen in time.

#### M3. Stripe SDK is six majors behind (and payments are placeholder)
- **Evidence:** `bundle outdated` → `stripe 13.5.1 → 19.2.0`, pinned `~> 13.0` in the Gemfile. README documents payments as intentionally placeholder (webhook only logs `checkout.session.completed`, no fulfillment).
- **Consequence (Risk — low today):** No active subscriptions, so blast radius is small, but the pin will block security patches within the 13.x line's EOL window and the gap grows before real billing ships.
- **Recommendation:** Fine to defer until billing is real, but track it; when you wire fulfillment, jump to a current `~> 19` line in the same PR. Other outdated gems (OTel suite, `image_processing`, `kramdown`) are minor — schedule a routine `bundle update` pass.
- ✅ **PARTIALLY CLEARED (2026-06-06):** ran the routine `bundle update` pass on the minor/OTel tail — `bootsnap`, `brakeman`, `jbuilder`, `mocha`, `propshaft`, `selenium-webdriver`, `solid_queue`, `thruster`, `web-console`, `kamal`, and the full OpenTelemetry suite (SDK `1.10→1.12`; exporter/instrumentation 0.x pins bumped a minor each in the `Gemfile`, e.g. `opentelemetry-exporter-otlp 0.31.1→0.34.0`, keeping the author's patch-pin style). Suite green (150 runs, 0 failures, OTel test included); `bundler-audit` still clean. **Deliberately deferred:** the `stripe` major bump (`13→19`) and the `solid_cable`/`image_processing` major bumps — left for the billing PR / a dedicated upgrade, per the recommendation above.

### Good (specific strengths worth preserving)

- **G1. Safe-by-default tenancy.** Controllers uniformly scope via `current_workspace.<assoc>.find` (`documents_controller.rb:6,11`, `recording_sessions_controller.rb:27,32`, `transformer_profiles_controller.rb:66`). The channel rejects on missing user/workspace and re-scopes the session lookup (`live_transcription_channel.rb:12-15`); `ApplicationCable::Connection` rejects unauthorized and only accepts `active_only` users (`connection.rb:13-20`). Preserve this convention — it's the app's strongest property.
- **G2. Defensive auth.** `sessions_controller.rb`: `reset_session` before setting `user_id` (fixation defense), SHA-256-keyed throttle that **raises `CacheUnavailableError` to fail closed** rather than silently allowing logins, and `user.active?` gating. Password complexity is centralized in `User` and reused by registration via a temp-user validation (`registrations_controller.rb:71`).
- **G3. Migration discipline.** `20260606103106_change_transformer_profile_instructions_null.rb` uses the full safe NOT-NULL pattern (`add_check_constraint validate: false` → `validate_check_constraint` → `change_column_null` → drop), with `disable_ddl_transaction!`. `strong_migrations` is configured against the real prod Postgres version (16) with lock/statement timeouts.
- **G4. Clean automated sweep.** RuboCop: 136 files, 0 offenses (rails-omakase + deliberately loose Metrics guards). Brakeman 8.0.2: 0 warnings. bundler-audit: 0 vulnerabilities (advisory DB current). No secrets in HEAD or git history; `master.key` untracked, only encrypted `credentials.yml.enc` committed.
- **G5. Production hardening present.** `config/environments/production.rb`: `assume_ssl`, `force_ssl`, HSTS/secure cookies, host authorization via `RAILS_ALLOWED_HOSTS`, with health endpoints excluded from the SSL redirect.
- **G6. Tests cover the risk surface, fast.** Dedicated tests for `dashboard_tenancy`, `sessions_security`, `payments_stripe_integration` (stubbed, no network), and `live_transcription_channel`. Seeds are guarded to dev/`ALLOW_DEMO_SEEDS` with per-run random passwords, and there's a `seeds_security_test` asserting it.

---

## 3. Quick Wins vs. Real Investment

**Quick wins (cheap, high value):** — ✅ all three done 2026-06-06
- [x] Add the unique index on `documents.recording_session_id` and clear the matching baseline (B2) — one migration. *(`20260606130000`, + `Document` uniqueness validation)*
- [x] Drop the 5 redundant indexes and empty most of the `database_consistency` todo (M1) — one migration. *(`20260606130100`; todo down to 2 benign entries)*
- [x] `bundle update` the OTel/minor gems (M3 tail). *(OTel suite + 10 minor gems; stripe/solid_cable majors deferred)*

**Real investment (worth the effort):**
- **CI workflow (B1)** — the one item that meaningfully changes the launch posture. Half a day to get `make check` running in Actions with a Postgres service and a required-check branch rule.
- Stripe upgrade + real fulfillment when billing becomes a priority (M3) — bundled with the feature, not before.

---

## 4. Enforcement Recommendations

1. **GitHub Actions = the gate.** One workflow on `push` + `pull_request` to `main`:
   - `postgres:16` service container; `RAILS_ENV=test`.
   - Steps mirroring `make check`: `bin/rails db:migrate` (so `strong_migrations` actually fires — note `db:test:prepare` does *not* run migrations), `bin/rubocop`, `bundle exec database_consistency`, `bin/rails test`, `bin/rails test:system`, plus `bundle exec brakeman -q` and `bundle exec bundler-audit check --update`.
   - Mark it a **required status check**; protect `main` against direct pushes.
2. **RuboCop cops/thresholds:** current config is sound. The loose Metrics guards (`MethodLength: 45`, `ClassLength: 250`, `AbcSize: 50`) are good regression guards — keep them, and ratchet down opportunistically since the app sits well under them today. Add `bundler-audit` and `brakeman` to the same CI job so dependency/security regressions fail the build, not just lint.
3. **`database_consistency` as a ratchet:** keep it in `make lint`/CI, but treat the `.todo.yml` as a burn-down list — every PR that touches a flagged model should shrink it. Consider a periodic check that the baseline only ever gets smaller.
4. **Optional pre-push hook:** add a `.githooks/pre-push` running `make check-fast` for fast local feedback, but rely on CI as the source of truth (hooks are bypassable with `--no-verify`; required CI checks are not).

---

**Bottom line:** Code quality is launch-ready and notably above average for a solo-built Rails SaaS — the findings are about *closing the last data-integrity gap (B2)* and *making the existing excellent gate automatic (B1)*, not about fixing broken code. Ship the CI workflow before you open the repo.