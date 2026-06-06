# Nodl — Pre-Launch Audit: Corrective Actions

**Date:** 2026-06-06
**Companion to:** [`code-quality-audit-pre.md`](./code-quality-audit-pre.md)
**Scope:** Implementation of the four "Quick Win" remediations from the pre-launch audit.

This document records the corrective actions taken against findings raised in the
pre-launch audit, the verification evidence for each, and what remains open.

---

## Summary

Four findings were remediated and verified: **B2**, **B3**, **B4** (all "Bad /
needs improvement") and **M3** ("Mid"). All changes are code/config only — no
schema or behavioral changes to existing features. The full test suite and
linters were green after the work.

| Finding | Severity | Status | Verification |
|---|---|---|---|
| B2 — Puma High-severity CVEs | 🔴 Bad | ✅ Cleared | `bundle-audit`: no vulnerabilities |
| B3 — Image ships `private/` | 🔴 Bad | ✅ Cleared | `.dockerignore` excludes local-only dirs |
| B4 — `bin/brakeman` self-disables | 🔴 Bad | ✅ Cleared | `bin/brakeman` scans, 0 warnings |
| M3 — `current_workspace` nil-safety | 🟡 Mid | ✅ Cleared | RuboCop clean; 150 tests, 0 failures |

**Files touched** (`git diff --stat`):

```
.dockerignore                                      |  7 +++++++
Gemfile.lock                                       |  2 +-
app/controllers/application_controller.rb          | 10 ++++++++++
app/controllers/documents_controller.rb            |  1 +
app/controllers/recording_sessions_controller.rb   |  4 +---
app/controllers/transformer_profiles_controller.rb |  5 -----
bin/brakeman                                       |  2 --
7 files changed, 20 insertions(+), 11 deletions(-)
```

---

## B2 — Bundled Puma has two High-severity CVEs

**Action:** Updated Puma to a patched release.

- `bundle update puma` — `Gemfile.lock` now pins `puma (8.0.2)` (was `7.2.0`).
- `Gemfile` constraint was already `>= 5.0`, so no edit was required there;
  the lockfile is the source of truth for the installed version.

**Resolves:** `CVE-2026-47736` (PROXY protocol remote memory exhaustion) and
`CVE-2026-47737` (PROXY header smuggling).

**Verification:**

```
$ bundle exec bundle-audit check --update
...
No vulnerabilities found
```

**Operational note:** the lockfile and the in-container gem are on 8.0.2, but a
long-running dev container still has the old Puma loaded in memory. Run
`make down && make up` to restart the server on the patched version. Tests and
CI are unaffected (they load fresh from the bundle).

---

## B3 — Production Docker image ships the secret-bearing `private/` directory

**Action:** Excluded local-only directories from the Docker build context.

Added to `.dockerignore`:

```
# Local-only directories that must never enter an image.
# private/ is the reserved home for repo-private secrets and a companion repo.
private
work
test
doc
```

**Why this is safe for development:** `.dockerignore` only affects the *build
context* (what `COPY . .` pulls into an image). The dev container does not rely
on the baked-in copy — `docker-compose.yml` bind-mounts `.:/rails` at runtime —
so `test/` and `doc/` remain fully available and `make test` is unaffected. The
exclusion only shrinks the production image and keeps `private/` (and generated
`work/` session artifacts) out of it.

**Verification:** confirmed the dev `web` service mounts `- .:/rails`
(`docker-compose.yml`); the full test suite still passes when run inside the
container.

**Follow-up (optional, not yet done):** add a CI assertion that the build
context excludes `private/` to prevent regression.

---

## B4 — `bin/brakeman` binstub self-disables via `--ensure-latest`

**Action:** Removed the line that forced the binstub to abort unless it was the
very latest Brakeman release.

`bin/brakeman` before:

```ruby
require "bundler/setup"

ARGV.unshift("--ensure-latest")

load Gem.bin_path("brakeman", "brakeman")
```

`bin/brakeman` after:

```ruby
require "bundler/setup"

load Gem.bin_path("brakeman", "brakeman")
```

**Effect:** `bin/brakeman` now performs a real scan instead of exiting early
with a version-mismatch message, so it is safe to call from CI and gives
accurate local results.

**Verification:**

```
$ bin/brakeman --summary
...
Controllers: 12
Security Warnings: 0
```

---

## M3 — `current_workspace` nil-safety is inconsistent across controllers

**Action:** Introduced a single shared guard and applied it to every
workspace-scoped controller, replacing ad-hoc inline checks and a duplicated
local copy.

1. **`ApplicationController`** — added a shared private method:

   ```ruby
   # Guards workspace-scoped controllers: every signed-in user is expected to
   # have a workspace (registration and admin-create both build one), so a nil
   # here means a clean redirect instead of a NoMethodError on current_workspace.
   def require_workspace!
     @workspace = current_workspace
     return if @workspace

     redirect_to dashboard_path, alert: t("flash.no_workspace")
   end
   ```

2. **`DocumentsController`** — added `before_action :require_workspace!`
   (previously called `current_workspace.documents…` with no nil guard).

3. **`RecordingSessionsController`** — added `before_action :require_workspace!`
   and removed the now-redundant inline `@workspace`/nil-check from `#create`.

4. **`TransformerProfilesController`** — removed its private duplicate of
   `require_workspace!`; it now uses the shared `ApplicationController` version
   (the `before_action :require_workspace!` was already present).

5. **`DashboardController`** — intentionally left unchanged. It renders a graceful
   empty state when there is no workspace and is the redirect *target* of the
   guard, so requiring a workspace there would be wrong (and could loop).

**Effect:** a signed-in user with zero workspaces now gets a clean redirect to
the dashboard with a flash message instead of a `NoMethodError` → 500. This
defends the "every user has a workspace" invariant rather than relying on it.
Net code reduction (the shared guard removed one inline check and one duplicate
method).

**Verification:**

```
$ bin/rubocop app/controllers bin
12 files inspected, no offenses detected

$ bin/rails test
150 runs, 641 assertions, 0 failures, 0 errors, 0 skips
```

The existing cross-tenant intrusion tests (e.g. "cannot manage a format from
another workspace" → 404) still pass, confirming the guard did not weaken tenant
isolation: users who *have* a workspace but request a foreign record still get a
`RecordNotFound`/404 from the scoped lookup.

---

## Post-change verification (full)

Run inside the `web` container after all four changes:

- `bundle-audit` — **No vulnerabilities found**
- `bin/brakeman` — 12 controllers, **0 security warnings**
- `bin/rubocop` — **0 offenses**
- `bin/rails test` — **150 runs, 641 assertions, 0 failures, 0 errors, 0 skips**

---

## Remaining open findings (not in scope for this pass)

From the pre-launch audit, the following remain open and are recommended next:

- **B1 — No CI pipeline.** Highest-leverage remaining item. A GitHub Actions
  workflow running RuboCop, Brakeman (via `bundle exec`), `bundle-audit`, and the
  test suite on every push/PR would institutionalize the four fixes above and
  prevent regression (e.g. a future PR re-adding a vulnerable gem).
- **M1 — RuboCop is a formatter, not a complexity gate** (omakase disables
  `Metrics/*`). Optional loose thresholds.
- **M2 — Data migrations reference application models directly.** Acceptable for
  now; prefer raw SQL / inlined classes for future data migrations.
- **M4 — No coverage tooling (SimpleCov).** Add to produce an untested-path map.

See [`code-quality-audit-pre.md`](./code-quality-audit-pre.md) §3–§4 for details
and exact commands.
