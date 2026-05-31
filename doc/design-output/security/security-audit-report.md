# Security Audit Report

Generated: 2026-02-22
Scope: Nodl Rails app (code + config + dependency scans)

## Summary

| Severity | Count |
|---|---:|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 3 |
| LOW | 1 |

Verified strengths:
- AuthN/AuthZ guards are present for protected surfaces (`authenticate_user!`, `require_admin!`) and tenancy switching is scoped to memberships.
- Production config enforces HTTPS and host allow-listing.
- Sensitive params are filtered from logs.

## Findings

### S-001 · Predictable Seed Credentials Can Enable Account Takeover · Severity: HIGH · Confidence: 95%

**Status: RESOLVED (2026-02-22)**

**Where:** `db/seeds.rb:24`

**Issue:** The seed script creates fixed, publicly documented credentials (`admin@example.com` / `Admin1234`, `demo@example.com` / `Demo1234`) every time seeds run.

**Impact:** If `db:seed` (or `db:seed:replant`) is ever run against a non-development environment, attackers can authenticate with known credentials and obtain admin access.

**Evidence:** `db/seeds.rb:24` and `db/seeds.rb:25` create deterministic users and passwords.

**Fix:**
- Gate seeded demo users by environment and explicit opt-in flag (for example `return unless Rails.env.development? || ENV["ALLOW_DEMO_SEEDS"] == "1"`).
- Replace hardcoded passwords with randomly generated values printed once in local-only workflows.
- Add a regression test that seed tasks do not create default credentials in production-like environments.
- Re-run: `bin/rails test` and seed-related CI step.

**Resolution (2026-02-22):** All three remediation steps were applied and verified:
- `db/seeds.rb` now returns early at line 3 unless `Rails.env.development?` or `ENV["ALLOW_DEMO_SEEDS"] == "1"`, preventing any seeding in production or staging environments.
- Hardcoded passwords `Admin1234` and `Demo1234` were replaced with `SecureRandom.hex(12)` (lines 31-32), generating fresh random values each run and printing them once to stdout only — never persisted anywhere.
- `test/integration/seeds_security_test.rb` was added with two regression cases: (1) seeds are a no-op in the non-development test environment without the flag; (2) seeds correctly create both users when `ALLOW_DEMO_SEEDS=1` is set. Both tests pass.
- `README.md` and `doc/index.md` were updated to remove references to the old hardcoded credentials and document the new behavior.

---

### S-002 · CSP Is Overly Permissive for Script/Style Sources · Severity: MEDIUM · Confidence: 93%

**Where:** `config/initializers/content_security_policy.rb:9`

**Issue:** `script-src` currently allows all HTTPS origins (`:https`), and `style-src` allows `:unsafe_inline`.

**Impact:** This weakens CSP as an XSS containment layer. If any markup/script injection path appears later, the policy is less likely to block exploitation.

**Evidence:**
- `config/initializers/content_security_policy.rb:9` (`policy.script_src :self, :https`)
- `config/initializers/content_security_policy.rb:10` (`policy.style_src :self, :unsafe_inline`)

**Fix:**
- Restrict `script-src` to explicit trusted origins only (for example `:self` plus exact Stripe domains actually needed).
- Remove `:unsafe_inline` from `style-src` if possible and rely on CSP nonces/hashes where inline styles are required.
- Validate Stripe checkout/payment flows after tightening CSP.
- Re-run: system tests covering payments and UI pages.

---

### S-003 · Password Strength Enforcement Is Inconsistent Across Account Flows · Severity: MEDIUM · Confidence: 92%

**Where:** `app/controllers/admin/users_controller.rb:101`

**Issue:** Registration enforces complexity (upper/lower/digit), but admin create/update flows only enforce minimum length (or no policy beyond model defaults).

**Impact:** Admin-created or admin-updated users can receive weak passwords, reducing resistance to credential stuffing and brute-force attacks.

**Evidence:**
- Complexity check exists in `app/controllers/registrations_controller.rb:69` and `app/controllers/registrations_controller.rb:75`.
- Admin password update only checks length in `app/controllers/admin/users_controller.rb:101`.

**Fix:**
- Centralize password policy in `User` model validation (single source of truth).
- Remove controller-only policy checks and rely on model validation errors.
- Add tests covering registration + admin create + admin update paths for identical password rules.
- Re-run: `bin/rails test test/system/admin_user_management_test.rb test/integration/sessions_security_integration_test.rb`.

---

### S-004 · Login Throttling Fails Open on Cache Errors · Severity: MEDIUM · Confidence: 90%

**Where:** `app/controllers/sessions_controller.rb:54`

**Issue:** Throttling methods rescue `StandardError` and return non-blocking behavior (`false`/`nil`). If cache backend is unavailable, failed-login tracking and blocking are effectively disabled.

**Impact:** During cache outages or cache misconfiguration, brute-force resistance drops substantially.

**Evidence:**
- `app/controllers/sessions_controller.rb:57-58` returns `false` on errors in `login_throttled?`.
- `app/controllers/sessions_controller.rb:69-70` swallows write failures in `record_failed_login_attempt`.

**Fix:**
- Fail closed for authentication attempts when throttling backend is unhealthy (temporary 429/503), or use a resilient fallback counter store.
- Emit structured alerting when throttling storage errors occur.
- Add integration tests simulating cache failures and asserting safe behavior.
- Re-run: auth integration tests.

---

### S-005 · Public Readiness Endpoint Exposes Backend Health State · Severity: LOW · Confidence: 88%

**Where:** `config/routes.rb:7`

**Issue:** `/readyz` is unauthenticated and exposes DB connection status (`ok`/`error`) in JSON/HTML.

**Impact:** External users can use this endpoint for operational reconnaissance and outage timing.

**Evidence:**
- Public route in `config/routes.rb:7`.
- Status response logic in `app/controllers/pages_controller.rb:16-27`.

**Fix:**
- Restrict `/readyz` to trusted networks, or require a shared secret/header at edge proxy.
- Keep `/healthz` as minimal liveness and make `/readyz` private for orchestrator checks.
- Re-test uptime/health integrations after restriction.

---

## Scanner Outputs

- Brakeman: `bin/brakeman --no-pager` via `.codex/skills/security-auditor/scripts/security_audit.sh` (Docker `web` runtime).
  - Summary: executed successfully (Scan Date: `2026-02-22 10:20:27 +0000`); 0 security warnings (`tmp/security-audit/brakeman.txt`).
- bundler-audit: `bin/bundler-audit` via `.codex/skills/security-auditor/scripts/security_audit.sh` (Docker `web` runtime).
  - Summary: executed successfully; no vulnerable gems reported (`tmp/security-audit/bundler-audit.txt`).
- importmap audit: `bin/importmap audit` via `.codex/skills/security-auditor/scripts/security_audit.sh` (Docker `web` runtime).
  - Summary: executed successfully; no vulnerable packages found (`tmp/security-audit/importmap-audit.txt`).

## Recommended Next Steps (ordered)

1. Fix MEDIUM
2. Fix LOW
3. Keep scanner execution containerized to avoid host Ruby/Bundler drift
