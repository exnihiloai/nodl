# Developer Guidelines

## Introduction

You are working on this project as a coding assistant and have access to terminal tools.
Use commands pragmatically to validate your work (tests, lint, setup checks).

This repository is a **Ruby on Rails 8 SaaS boilerplate**.
Default runtime is Docker Compose; default workflow is via `make` targets.

**IMPORTANT**: before handing off work that involved code changes to the app, run the full test suite with `make test`.
Partial runs are fine while iterating, but final verification is always `make test`.
If you add or change behavior, add or update tests to cover it.

---

## Core Principles

- **HTML-first SSR**: Rails renders HTML with ERB templates.
- **Turbo over custom AJAX**: Prefer Turbo navigation and Turbo Streams for partial page updates.
- **Minimal JS**: Use Stimulus only for small, local UI behavior.
- **Rails conventions first**: RESTful routes, thin controllers, model validations/associations.
- **Production-minded defaults**: migrations, health endpoints, CSRF, secure config, logging.

---

## Rails App Shape

- App entry and configuration:
- `config/application.rb`
- `config/routes.rb`
- MVC layout:
- Controllers: `app/controllers/`
- Models: `app/models/`
- Views: `app/views/`
- Database:
- Migrations: `db/migrate/`
- Schema snapshot: `db/schema.rb`
- Seeds: `db/seeds.rb`

Health endpoints are available at:
- `/healthz`
- `/readyz`

---

## Views, Partials, and Turbo

- Full pages should use layout + ERB templates.
- Reusable sections should be extracted into partials (`_partial.html.erb`).
- For dynamic updates, prefer Turbo-compatible responses rather than bespoke JS.
- Keep canonical URLs for full-page refresh behavior.

Patterns to prefer:
- `link_to` and `button_to` with Rails path helpers.
- Turbo-friendly form submissions with clear success/error rendering.
- Partial replacement only for the smallest meaningful UI fragment.

---

## Stimulus Usage (Keep It Small)

Use Stimulus for:
- toggles
- theme switching
- tiny local interaction state

Do not use Stimulus for:
- business logic
- server orchestration that belongs in controllers/models
- SPA-style global state management

Keep controllers focused and short; if it gets complex, revisit server-rendered flow first.

---

## Tailwind + DaisyUI

- Use DaisyUI components as UI primitives for consistency.
- Keep styling mostly utility-first in templates.
- Put repeated design tokens and theme overrides in:
- `app/assets/tailwind/application.css`
- Avoid large custom CSS unless clearly justified.

Theme behavior must stay consistent across:
- light mode
- dark mode
- custom project theme variants

---

## Auth, Tenancy, and Admin Rules

- Authentication is Rails-native session auth using `has_secure_password`.
- Multi-tenancy is workspace/membership based.
- Always scope tenant-relevant queries and actions to the current workspace context.
- Admin features live under `Admin::` namespace and must remain protected.

Current key flows include:
- `/register`, `/login`, `/logout`
- `/dashboard`
- `/admin/users`

---

## Stripe Placeholder Rules

Stripe integration is currently placeholder-level but must behave predictably.

Routes:
- `/payments`
- `/payments/checkout`
- `/payments/success`
- `/payments/cancel`
- `/payments/webhook`

Guidelines:
- Guard behavior when Stripe env vars are missing.
- Return clear user-facing fallbacks on checkout/webhook failures.
- In tests, stub Stripe calls; no external network dependency.

---

## Forms, Validation, and Errors

- Validate at the model level and enforce constraints at the DB layer where appropriate.
- Keep controller error handling explicit and user-readable.
- Re-render forms with inline error feedback when validation fails.
- Use flash messages for global success/error feedback.

---

## Security Baseline

- Never commit secrets.
- Use environment variables for sensitive config (especially Stripe keys/secrets).
- For git operations treat `private/` as ignored local/private companion-repo. Never commit anything in that folder.
- Keep CSRF protections enabled except for explicit endpoints that require exclusion (e.g. webhook endpoint with signature validation).
- Respect secure defaults in Rails and avoid weakening session/cookie protections.

---

## Database & Migration Workflow

For schema changes:
1. Create a Rails migration.
2. Update model associations/validations.
3. Run migrations and verify `db/schema.rb` changes.
4. Add or update tests for behavior and data integrity.

Rules:
- Prefer reversible migrations.
- Do not edit historical migrations unless explicitly required.
- Keep seed data safe and deterministic for local onboarding.

---

## Testing & QA

Default commands:
- `make lint`
- `make test`

`make test` runs:
- `bin/rails test`
- `bin/rails test:system`

Testing expectations:
- Add tests for any changed behavior.
- Favor stable, fast tests.
- Use integration tests for controller/HTTP behavior.
- Use system tests for key user flows.
- Avoid flaky browser-dependent assertions when request/integration coverage is sufficient.

---

## Local Development Workflow

Primary commands:
- `make build`
- `make up`
- `make dev`
- `make logs`
- `make shell`
- `make seed`
- `make lint`
- `make test`
- `make down`

Use these Make targets instead of ad-hoc command variants whenever possible.

---

## Git and Collaboration Rules

- Do not commit unless the user explicitly asks.
- Do not rewrite history unless explicitly asked.
- Do not revert unrelated user changes.
- Keep changes scoped and minimal.
- Update docs when behavior/workflow changes.

---

## Repo Hygiene

- Keep OS/editor artifacts out of version control (`.DS_Store`, temp files, local caches).
- Keep generated or machine-specific files out of commits unless intentionally required.
- Keep `private/` out of the public repository. It is reserved for private test data, local deployment config, notes, or other non-public companion files.
- Preserve a clean, reproducible developer workflow for new contributors.

---

## Quick Pointers

- Routes: `config/routes.rb`
- Main layout: `app/views/layouts/application.html.erb`
- Theme and Tailwind setup: `app/assets/tailwind/application.css`
- Payments flow: `app/controllers/payments_controller.rb`
- Dev commands: `Makefile`
- Tests: `test/`
