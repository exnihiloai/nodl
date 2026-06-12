# Agent Orientation

Read before large changes. Also: `README.md`, `AGENTS.md`, `doc/index.md`.

Rails 8 SSR SaaS (auth, tenancy, admin, Stripe placeholder, audio→document). **Docker-only** dev: `make build`, `make up` → `http://localhost:3000`. i18n: `en.yml` source, sync `de.yml`.

## OSS vs `private/`

| | OSS | `private/` (gitignored companion content) |
|---|---|---|
| Code | `app/`, `config/`, routes, tests | `.env`, `initializers/*.rb`, operator-specific views/locales |
| Marketing | generic app shell + private-content hooks | landing/vertical/about/try-now templates and marketing copy |
| Legal | `LegalPage` + routes wire footer links | Impressum/privacy/terms **content** |

Load hook: `config/initializers/private_loader.rb` loads private initializers/locales; `ApplicationController` prepends `private/views` per request. Dev bind-mounts `private/`; prod must mount or bake required private content at deploy. **Do not touch `private/` unless user asks.**

## Env (later wins)

`.env` → `private/.env` → `docker-compose.yml` `environment:`. Local `RAILS_ENV=development` set by Compose. Secrets/API keys → `private/.env`. Telegram in dev sends only if `ALLOW_DEV_TELEGRAM_NOTIFICATIONS=true`.

## Errors

| Dev | Prod/test |
|---|---|
| Rails debug UI (Routing Error) | Friendly 404 via `ErrorsController` + `exceptions_app` |

Preview branded 404 locally: `/404`. No `public/404.html`.

## Handoff gate

`make check` must pass (db-check + lint + tests). Inner loop: `make check-fast`. Commit `db/schema.rb` after migrations.

## Pointers

Routes `config/routes.rb` · Layout `app/views/layouts/application.html.erb` · Private content boundary `lib/private_content.rb` · Limits `app/models/plan_limits.rb` · Icons `skills/icon-import-lucide-rails/` · Skills `.codex/skills/`

**Do:** Docker commands, thin controllers, tests for behavior changes, minimal diffs. **Don't:** commit secrets/`private/`, skip `make check`, CDN icons, legal copy in OSS locales.
