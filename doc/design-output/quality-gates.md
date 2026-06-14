# Quality Gates

Nodl ships one handoff gate that must pass before any change lands, plus several independently runnable checks for security scanning and coverage.

## The handoff gate

Before handing off significant changes, run the single handoff gate — it must pass:

```sh
make check        # db-check + lint + full tests (unit/integration + system)
```

For the inner development loop, a faster variant skips the browser/system tests:

```sh
make check-fast   # db-check + lint + unit/integration tests only
```

`make check` is the aggregate of three steps, each runnable on its own:

- `make db-check` — applies pending migrations (so [strong_migrations](https://github.com/ankane/strong_migrations) actually runs and aborts on unsafe operations) and asserts `db/schema.rb` is in sync (fails if a migration was added but not applied/committed).
- `make lint` — see below.
- `make test` — see below.

### Lint

`make lint` runs, inside the container:

- `bin/rubocop` — style + a few loose complexity cops.
- `bundle exec database_consistency` — checks that model validations/associations are backed by DB constraints (FKs, NOT NULL, unique indexes). Pre-existing findings are baselined in `.database_consistency.todo.yml`; only *new* mismatches fail the check. Triage that baseline over time.

### Test

`make test` runs:

- `bin/rails test`
- `bin/rails test:system` with `JS_SYSTEM_TESTS=1`

Migration safety is enforced by [strong_migrations](https://github.com/ankane/strong_migrations), which runs automatically during `bin/rails db:migrate` and aborts on unsafe operations. It fires wherever migrations actually run — `make up` (`db:prepare`) and `make db-check`. Note that `make test` uses `db:test:prepare` (a schema load), which does **not** run migrations, so `make db-check` is what exercises strong_migrations in the handoff gate. Existing migrations are grandfathered via `start_after` in `config/initializers/strong_migrations.rb`; checks target Postgres 16.

JavaScript-specific system tests (microphone recorder, clipboard, theme switcher) are guarded by `JS_SYSTEM_TESTS=1` and skip without it. `make test` (and therefore `make check` and the CI `check` job on every merge request) sets the flag, running them against the headless Chromium in the dev image. `make test-js` runs just the system-test step on its own.

## Dependency CVE scanning

```sh
make audit        # bundler-audit check against the rubysec ruby-advisory-db
```

`make audit` scans the locked gems for known vulnerabilities using [bundler-audit](https://github.com/rubysec/bundler-audit). It uses a single, reliable source — the community [rubysec/ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db) — which it clones/refreshes locally and matches against `Gemfile.lock`, so **no dependency data leaves your machine**.

It is intentionally **not** part of `make check`: it needs network to refresh the advisory DB, and a newly disclosed advisory can fail it without any code change on your side. Run it periodically and before a deploy. Suppress advisories that genuinely do not apply by adding them to the `ignore:` list in `config/bundler-audit.yml`.

`make audit` only sees declared gems (`Gemfile.lock`). To scan a **built image** — the OS layer (Debian packages such as `openssl`), the gems actually on disk, and leaked secrets — use [Trivy](https://github.com/aquasecurity/trivy):

```sh
make image-audit IMAGE=repo:tag             # styled HTML report (or just `make image-audit` to use DEPLOY_IMAGE from private/.env)
make image-audit IMAGE=repo:tag FORMAT=txt  # plain-text table instead
```

It runs Trivy as a container, downloads its vulnerability DB into a local cache volume (so nothing about the image leaves your machine), and reports HIGH/CRITICAL findings that have a fix available. Instead of flooding the terminal it writes a timestamped report to `tmp/security/image-audit-<timestamp>.{html,txt}` (git-ignored) and prints just a one-line summary and the path. `FORMAT=html` (default) is a styled report you can open in a browser and print to PDF; `FORMAT=txt` is a plain table. It is **informational** — it does not fail — and is kept separate from `make audit` because an image scan is only meaningful against a freshly built image. OS-layer findings are cleared by rebuilding the image (a fresh `apt-get` pulls patched packages); run it before a deploy.

## Test coverage

Coverage is measured with SimpleCov and is **opt-in** (off by default so normal runs stay fast). Run it inside the container:

```sh
make coverage
```

This runs `COVERAGE=1 bin/rails test` in the `web` container and writes an HTML report to `./coverage/index.html` (git-ignored). The same opt-in works for ad-hoc runs:

```sh
docker compose exec -e COVERAGE=1 web bin/rails test
```

Treat the report as a map of untested paths, not a grade. System tests run in a separate process group and are not included in the figure, so real coverage of user-facing flows is higher.
