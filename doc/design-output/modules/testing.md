# Testing

## Running Tests

```bash
make test                          # rails test + rails test:system (inside Docker)
make lint                          # rubocop

# Single file
docker compose exec web bin/rails test test/models/user_test.rb

# JS system tests (Selenium; off by default)
JS_SYSTEM_TESTS=1 docker compose exec web bin/rails test test/system/theme_switcher_js_test.rb
```

## Test Structure

```
test/
  test_helper.rb                          # shared setup
  application_system_test_case.rb         # Capybara base class (headless Chrome)
  application_js_system_test_case.rb      # Capybara base class with JS enabled
  integration/
    payments_stripe_integration_test.rb   # Stripe checkout + webhook flows
    sessions_security_integration_test.rb # Auth throttling + deactivated user
  system/
    admin_user_management_test.rb         # Admin CRUD + audit events
    authentication_flow_test.rb           # Register, login, logout flows
    dashboard_tenancy_test.rb             # Workspace switching
    marketing_pages_test.rb               # Public shell/private marketing fallback
    payments_system_test.rb               # Payments page UI
    theme_switcher_js_test.rb             # Theme toggle (JS only)
```

## Test Conventions

- No external network calls. Stripe API calls are stubbed with `mocha`.
- System tests run headless Chrome by default. The `JS_SYSTEM_TESTS=1` env flag must be set explicitly to enable JavaScript in system tests (avoids slow Selenium runs in standard CI).
- Failed system test screenshots are uploaded as GitHub Actions artifacts.
- Database is `DATABASE_URL_TEST` (separate from development DB).

## CI Pipeline

GitHub Actions workflow: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)

| Job | Runs | Commands |
|---|---|---|
| `scan_ruby` | ubuntu-latest | `bin/brakeman --no-pager`, `bin/bundler-audit` |
| `scan_js` | ubuntu-latest | `bin/importmap audit` |
| `lint` | ubuntu-latest | `bin/rubocop -f github` (with cache) |
| `test` | ubuntu-latest + postgres service | `bin/rails db:test:prepare test` |
| `system-test` | ubuntu-latest + postgres service | `bin/rails db:test:prepare test:system` |

Triggers: all pull requests + pushes to `main`.

## Security Scanning

- `bin/brakeman` — static analysis for Rails security vulnerabilities
- `bin/bundler-audit` — known CVEs in Gem dependencies (config: [`config/bundler-audit.yml`](../../config/bundler-audit.yml))
- `bin/importmap audit` — known vulnerabilities in JS imports

All three run in CI before tests.
