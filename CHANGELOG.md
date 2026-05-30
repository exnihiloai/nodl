# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- **S-001 resolved:** Seed credentials can no longer enable account takeover. `db/seeds.rb` now returns early unless `Rails.env.development?` or `ENV["ALLOW_DEMO_SEEDS"] == "1"`, and demo user passwords are generated with `SecureRandom.hex(12)` (printed once to stdout, never stored). Regression tests added in `test/integration/seeds_security_test.rb`. `README.md` and `doc/index.md` updated to remove hardcoded credential references.

---

## [0.1.0] - 2026-02-21

Initial release of the Nodl Rails 8 SaaS boilerplate.

### Added

#### Core Application

- Rails 8 application scaffold with PostgreSQL database.
- Docker Compose setup for local development (`Dockerfile.dev`, `docker-compose.yml` with health checks and environment variable configuration).
- Makefile with developer shortcuts (`make build`, `make up`, `make dev`, `make seed`, `make test`, `make logs`, `make shell`, `make down`).
- `.env.example` documenting all required and optional environment variables.

#### Domain Model

- Multi-tenant domain: `User`, `Workspace`, `Membership` models with associations and validations.
- Role system on `User` (`:admin`, `:user`) and `Membership` (`:owner`, `:member`).
- Workspace subscription fields (`subscription_status`, `subscription_plan`, `subscription_billing_cycle`, `usage_limits`, `usage_consumption`).

#### Authentication & Authorization

- Session-based authentication with `has_secure_password`.
- Registration, login, and logout flows.
- Password complexity enforcement (uppercase, lowercase, digit) in registration.
- Login throttling with failed-attempt tracking via Rails cache.
- `authenticate_user!` and `require_admin!` guards on all protected surfaces.
- Admin namespace (`Admin::UsersController`) at `/admin/users` with audit event logging.

#### Multi-Tenancy

- `current_workspace` resolution scoped to user memberships.
- Workspace switching restricted to workspaces the current user belongs to.

#### Payments (Stripe Placeholder)

- Stripe Checkout placeholder flow: `/payments`, `/payments/checkout`, `/payments/success`, `/payments/cancel`.
- Webhook endpoint at `/payments/webhook`.
- Graceful handling of missing Stripe session URLs.

#### Frontend

- Tailwind CSS + DaisyUI for all UI components.
- DaisyUI stylesheet served locally (no CDN dependency).
- Inter font via local assets.
- Turbo + Stimulus for SPA-like interactions without a full SPA.
- Theme switcher (light/dark) implemented as a Stimulus controller.
- Lucide SVG icons imported locally.
- SSR marketing, dashboard, and admin pages.
- Liveness (`/healthz`) and readiness (`/readyz`) endpoints.

#### Observability

- OpenTelemetry instrumentation with export support for self-hosted SigNoz.

#### Security

- Content Security Policy initializer (`config/initializers/content_security_policy.rb`).
- HTTPS enforcement and host allow-listing in production config.
- Sensitive parameters filtered from logs.
- Security hardening pass (session/cookie settings, header defaults).

#### Testing

- Rails Minitest suite: unit, integration, and system tests.
- End-to-end system tests for authentication and admin user management.
- System tests for marketing pages, payments, and theme switcher (JS-guarded with `JS_SYSTEM_TESTS=1`).
- Stripe checkout/webhook integration tests with stubs (no network required).

#### AI Agent Infrastructure

- `CLAUDE.md` and `AGENTS.md` with project-specific agent collaboration rules.
- Skill generation framework (`.codex/skills/`) with shared scripts.
- Documentation Architect agent — generates structured docs under `doc/`.
- Documentation Auditor agent — audits `doc/` claims against source code.
- Security Auditor skill — runs Brakeman, bundler-audit, importmap audit, produces `doc/security-audit-report.md`.
- Security Hardener agent — applies fixes from the audit report.
- User Story Creator skill — scaffolds user story markdown files.
- Merge Feature Into Main agent — safe merge workflow with forced merge commit.
- Lucide icon import skill — imports SVG icons locally without CDN or Node runtime.

#### Documentation

- `README.md` with setup, daily commands, accounts, Stripe config, and AI collaboration workflow.
- `doc/` with architecture, data models, API, authentication, admin, payments, multi-tenancy, testing, and frontend module docs.
- Architecture Decision Records (ADRs) for session-based auth and Solid stack.
- Developer guidelines document (`developer-guidelines.md`).
- Example user story.
