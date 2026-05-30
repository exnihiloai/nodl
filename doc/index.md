# Nodl Documentation

Nodl is a Rails 8 SSR SaaS boilerplate providing authentication, multi-tenant workspaces, admin management, and Stripe payment scaffolding.

## Table of Contents

| Document | Description |
|---|---|
| [architecture.md](architecture.md) | System overview, stack, request lifecycle, deployment |
| [data-models.md](data-models.md) | Database schema, ActiveRecord models, relationships |
| [api.md](api.md) | All HTTP routes, controllers, request/response contracts |
| [modules/auth.md](modules/auth.md) | Session-based authentication and login throttling |
| [modules/tenancy.md](modules/tenancy.md) | Workspace multi-tenancy and membership model |
| [modules/admin.md](modules/admin.md) | Admin namespace, user management, audit events |
| [modules/payments.md](modules/payments.md) | Stripe Checkout integration and webhook handling |
| [modules/frontend.md](modules/frontend.md) | Tailwind, DaisyUI, Turbo, Stimulus, theme switching |
| [modules/testing.md](modules/testing.md) | Test structure, CI pipeline, conventions |
| [adr/001-session-auth.md](adr/001-session-auth.md) | ADR: session-based auth over token-based |
| [adr/002-solid-stack.md](adr/002-solid-stack.md) | ADR: Solid Cache / Queue / Cable over Redis |

## Audit Archive

Completed audit reports are moved to `doc/done/` to keep active docs clean:

| Report | Status |
|---|---|
| [done/audit-report-2026-02-21.md](done/audit-report-2026-02-21.md) | Closed (all findings fixed) |

## DaisyUI Reference

Maintained in [`doc/daisy-ui/`](daisy-ui/) (reference materials):

| File | Topic |
|---|---|
| [daisy-ui.md](daisy-ui/daisy-ui.md) | General DaisyUI overview |
| [daisy-ui-colors.md](daisy-ui/daisy-ui-colors.md) | Color tokens |
| [daisy-ui-fieldset.md](daisy-ui/daisy-ui-fieldset.md) | Fieldset component |
| [daisy-ui-modal.md](daisy-ui/daisy-ui-modal.md) | Modal component |
| [daisy-ui-tabs.md](daisy-ui/daisy-ui-tabs.md) | Tabs component |
| [daisy-ui-themes.md](daisy-ui/daisy-ui-themes.md) | Theme configuration |
| [daisy-ui-tooltips.md](daisy-ui/daisy-ui-tooltips.md) | Tooltips component |
| [daisy-ui-utility-css.md](daisy-ui/daisy-ui-utility-css.md) | Utility CSS helpers |

## Quick Start

```bash
cp .env.example .env
make build
make dev        # http://localhost:3000
make seed
make test
```

Seed accounts: `admin@example.com` (admin) and `demo@example.com` (user). Passwords are randomly generated and printed to the console during `make seed`. Seeds only run in development or when `ALLOW_DEMO_SEEDS=1` is set.
