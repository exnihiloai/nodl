# Architecture

## Stack

| Layer | Technology |
|---|---|
| Language | Ruby 3.3.10 |
| Framework | Rails 8.1.2 |
| Database | PostgreSQL 16 |
| Asset pipeline | Propshaft |
| CSS | Tailwind CSS + DaisyUI (via tailwindcss-rails) |
| JS delivery | Import Maps (importmap-rails) |
| Reactivity | Hotwire: Turbo + Stimulus |
| Background jobs | Solid Queue (DB-backed) |
| Caching | Solid Cache (DB-backed) |
| WebSockets | Solid Cable (DB-backed) |
| Web server | Puma (dev) / Thruster + Puma (production) |
| Deployment | Kamal |
| Containerisation | Docker (Dockerfile, Dockerfile.dev, docker-compose.yml) |

Source files: [`Gemfile`](../Gemfile), [`config/application.rb`](../config/application.rb), [`.ruby-version`](../.ruby-version)

## Design Philosophy

Rails 8 HTML-first SSR. No SPA. Pages are rendered server-side with ERB. Turbo Drive handles navigation (replaces full-page loads with fetch + DOM swap). Turbo Frames and Turbo Streams handle partial updates. Stimulus provides small, scoped UI behaviours only.

## Request Lifecycle

```
Browser request
  -> Thruster (HTTP/2 + asset caching, production only)
  -> Puma thread pool
  -> Rails router (config/routes.rb)
  -> ApplicationController before_actions
       authenticate_user! (if required)
       require_admin! (admin namespace)
       current_user / current_workspace (helpers)
  -> Feature controller action
  -> ERB view + layout (app/views/layouts/application.html.erb)
  -> Turbo response or redirect
```

## Rails Base Classes

Rails defines shared base classes/modules that features inherit from:

- [`app/models/application_record.rb`](../app/models/application_record.rb) — `ApplicationRecord < ActiveRecord::Base` with `primary_abstract_class`; all models inherit from this base.
- [`app/jobs/application_job.rb`](../app/jobs/application_job.rb) — `ApplicationJob < ActiveJob::Base`; contains the standard Rails retry/discard templates (currently commented).
- [`app/mailers/application_mailer.rb`](../app/mailers/application_mailer.rb) — `ApplicationMailer < ActionMailer::Base` with default sender (`from@example.com`) and `mailer` layout.
- [`app/helpers/application_helper.rb`](../app/helpers/application_helper.rb) — shared view helper module (currently empty).

## Multi-Database Configuration (Production)

Production uses four separate PostgreSQL databases managed via `config/database.yml`:

| Database | Purpose |
|---|---|
| `nodl_production` | Primary application data |
| `nodl_production_cache` | Solid Cache |
| `nodl_production_queue` | Solid Queue |
| `nodl_production_cable` | Solid Cable |

Development uses a single `DATABASE_URL` env var for both primary and secondary connections.

Source: [`config/database.yml`](../config/database.yml)

## Deployment (Kamal)

Deployment is managed by Kamal v2. Configuration lives in [`config/deploy.yml`](../config/deploy.yml).

Key settings:
- Service name: `app`
- Target server: configured via `servers.web` (placeholder `192.168.0.1`)
- Registry: `localhost:5555` (placeholder — override for production)
- Secret injected: `RAILS_MASTER_KEY`
- `SOLID_QUEUE_IN_PUMA: true` — job supervisor runs inside Puma process on single-server deployments
- Assets bridged across deploys at `/rails/public/assets`
- Build arch: `amd64`

Kamal aliases available:
```bash
bin/kamal console   # rails console on server
bin/kamal shell     # bash on server
bin/kamal logs      # tail logs
bin/kamal dbc       # rails dbconsole
```

## Docker

| File | Purpose |
|---|---|
| [`Dockerfile`](../Dockerfile) | Multi-stage production image; runs as non-root user (`USER 1000:1000`, group/user both named `rails`) |
| [`Dockerfile.dev`](../Dockerfile.dev) | Single-stage dev image with build tools; hot-reloads code from bind mount |
| [`docker-compose.yml`](../docker-compose.yml) | Local stack: `db` (postgres:16) + `web` (Dockerfile.dev); bind mounts repo |

Production image boots via `./bin/thrust ./bin/rails server`.

The `Dockerfile.dev` default CMD performs a one-shot Tailwind build then starts the server: `bin/rails tailwindcss:build && bin/rails db:prepare && bin/rails s`. When started via `docker compose up`, the Compose `command:` override replaces this CMD with `bin/rails db:prepare && (bin/rails tailwindcss:watch[always] & bin/rails server)`, enabling live CSS recompilation. Running the dev image directly with `docker run` (without Compose) will **not** get a watch process.

## Recurring Jobs

Configured in [`config/recurring.yml`](../config/recurring.yml). In production, `SolidQueue::Job.clear_finished_in_batches` runs every hour at minute 12.

## Security Defaults

- CSP configured in [`config/initializers/content_security_policy.rb`](../config/initializers/content_security_policy.rb):
  - `default-src 'self'`, `base-uri 'self'`, `frame-ancestors 'none'`, `object-src 'none'`
  - `script-src 'self' https:` — allows scripts from self **and any HTTPS origin** (not nonce-only; nonces are generated and injected but `:https` makes them non-enforcing for external scripts)
  - `style-src 'self' 'unsafe-inline'` — nonces are generated for styles but `unsafe-inline` coexists, which means inline styles without nonces are also permitted
  - `frame-src`: Stripe domains whitelisted (`js.stripe.com`, `hooks.stripe.com`, `checkout.stripe.com`)
  - Nonce generator is active (`content_security_policy_nonce_auto: true`), but the effective policy is permissive rather than strict-nonce due to the above.
- CSRF enabled everywhere except `POST /payments/webhook` (validated by Stripe signature instead).
- Login throttle: 10 failures per 10-minute window triggers a 15-minute block keyed by `SHA256(email|ip)`.
- Modern browsers only enforced via `allow_browser versions: :modern`.

## Observability (OpenTelemetry)

Optional OpenTelemetry export is configured entirely via environment variables and initialized at boot:

- `OTEL_EXPORTER_OTLP_ENDPOINT` enables baseline traces + metrics export.
- `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` enables log export (or falls back to `${OTEL_EXPORTER_OTLP_ENDPOINT}/v1/logs`).
- `OTEL_INGEST_TOKEN` is attached as OTLP headers for auth.
- `OTEL_SERVICE_NAME` sets `service.name` on emitted telemetry resources.

If OTEL env vars are missing or invalid, boot continues and a warning is logged.
