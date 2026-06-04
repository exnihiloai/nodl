# Nodl Documentation

Nodl is a Rails 8 SSR SaaS application with authentication, workspace tenancy, admin management, Stripe payment scaffolding, and an emerging audio-to-document pipeline.

This documentation is organized by document purpose:

- `design-input/` contains requirements, user stories, domain notes, and exploratory design material.
- `design-output/` contains accepted architecture, API, data model, module, security, and ADR documentation.
- `third-party/` contains copied or curated reference material for external libraries and tools.

## Design Input

Design input documents describe what should be built, why it matters, and what constraints or domain rules shape the work.

| Document | Description |
|---|---|
| [design-input/architecture.md](design-input/architecture.md) | Architecture notes and design input |
| [design-input/custom-transformers/design.md](design-input/custom-transformers/design.md) | Custom transformers design: user-defined instructions + reference documents (.docx, .odt, .pdf, .md, .txt) |
| [design-input/live-transcription/design.md](design-input/live-transcription/design.md) | ⚠️ **Outdated** (Gemini segmented-HTTP). Real implementation: [design-output/modules/live-transcription.md](design-output/modules/live-transcription.md) |
| [design-input/live-transcription/implementation-plan.md](design-input/live-transcription/implementation-plan.md) | ⚠️ **Outdated** plan for the abandoned Gemini approach |
| [design-input/live-transcription/test-plan.md](design-input/live-transcription/test-plan.md) | ⚠️ **Outdated** test plan for the abandoned Gemini approach |
| [design-input/domain/domain-model-pipeline.md](design-input/domain/domain-model-pipeline.md) | Audio recording, transcript, transformer, transformation, document, and versioning domain model |
| [design-input/testing/testing-guidelines.md](design-input/testing/testing-guidelines.md) | Testing philosophy and coverage guidance for trusted product behavior |
| [design-input/user-stories/2026-06-04-live-transcription.md](design-input/user-stories/2026-06-04-live-transcription.md) | User story for live transcription with speaker attribution |
| [design-input/user-stories/✅ 2026-05-30-audio-to-document-prototype.md](<design-input/user-stories/✅ 2026-05-30-audio-to-document-prototype.md>) | User story for the audio-to-document prototype |
| [design-input/user-stories/2026-02-21 opentelemetry-export-to-self-hosted-signoz.md](<design-input/user-stories/2026-02-21 opentelemetry-export-to-self-hosted-signoz.md>) | User story for OpenTelemetry export to self-hosted SigNoz |
| [design-input/user-stories/YYYY-MM-DD example-user-story.md](<design-input/user-stories/YYYY-MM-DD example-user-story.md>) | User story template/example |

## Design Output

Design output documents describe accepted or currently implemented system structure.

| Document | Description |
|---|---|
| [design-output/data-models.md](design-output/data-models.md) | Database schema, Active Record models, relationships |
| [design-output/api.md](design-output/api.md) | HTTP routes, controllers, request/response contracts |
| [design-output/modules/auth.md](design-output/modules/auth.md) | Session-based authentication and login throttling |
| [design-output/modules/tenancy.md](design-output/modules/tenancy.md) | Workspace multi-tenancy and membership model |
| [design-output/modules/admin.md](design-output/modules/admin.md) | Admin namespace, user management, audit events |
| [design-output/modules/payments.md](design-output/modules/payments.md) | Stripe Checkout integration and webhook handling |
| [design-output/modules/dashboard.md](design-output/modules/dashboard.md) | Authenticated audio-to-document dashboard, recording UX, live activity feed |
| [design-output/modules/audio-pipeline.md](design-output/modules/audio-pipeline.md) | Audio-to-Markdown pipeline used by CLI and dashboard processing |
| [design-output/modules/live-transcription.md](design-output/modules/live-transcription.md) | Realtime Voxtral live preview, batch diarization, waveform precompute, and the synced audio player |
| [design-output/modules/frontend.md](design-output/modules/frontend.md) | Tailwind, DaisyUI, Turbo, Stimulus, theme switching |
| [design-output/modules/testing.md](design-output/modules/testing.md) | Test structure, CI pipeline, conventions |

## Architecture Decision Records

ADRs record accepted architecture decisions, including context, decision, rationale, and consequences.

| Document | Description |
|---|---|
| [design-output/adr/001-session-auth.md](design-output/adr/001-session-auth.md) | ADR: session-based authentication over token-based auth |
| [design-output/adr/002-solid-stack.md](design-output/adr/002-solid-stack.md) | ADR: Solid Cache / Queue / Cable over Redis |

## Security

| Document | Description |
|---|---|
| [design-output/security/security-audit-report.md](design-output/security/security-audit-report.md) | Current security audit report |
| [design-output/security/done/audit-report-2026-02-21.md](design-output/security/done/audit-report-2026-02-21.md) | Closed audit report |
| [design-output/security/done/security-review-add-claude-support-2026-02-21.md](design-output/security/done/security-review-add-claude-support-2026-02-21.md) | Closed security review |

## Third-Party Reference

Maintained in [`third-party/daisy-ui/`](third-party/daisy-ui/) as local reference material.

| Document | Topic |
|---|---|
| [third-party/daisy-ui/daisy-ui.md](third-party/daisy-ui/daisy-ui.md) | General DaisyUI overview |
| [third-party/daisy-ui/daisy-ui-colors.md](third-party/daisy-ui/daisy-ui-colors.md) | Color tokens |
| [third-party/daisy-ui/daisy-ui-fieldset.md](third-party/daisy-ui/daisy-ui-fieldset.md) | Fieldset component |
| [third-party/daisy-ui/daisy-ui-modal.md](third-party/daisy-ui/daisy-ui-modal.md) | Modal component |
| [third-party/daisy-ui/daisy-ui-tabs.md](third-party/daisy-ui/daisy-ui-tabs.md) | Tabs component |
| [third-party/daisy-ui/daisy-ui-themes.md](third-party/daisy-ui/daisy-ui-themes.md) | Theme configuration |
| [third-party/daisy-ui/daisy-ui-tooltips.md](third-party/daisy-ui/daisy-ui-tooltips.md) | Tooltips component |
| [third-party/daisy-ui/daisy-ui-utility-css.md](third-party/daisy-ui/daisy-ui-utility-css.md) | Utility CSS helpers |

## Quick Start

```bash
cp .env.example .env
make build
make dev        # http://localhost:3000
make seed
make test
```

Seed accounts: `admin@example.com` (admin) and `demo@example.com` (user). Passwords are randomly generated and printed to the console during `make seed`. Seeds only run in development or when `ALLOW_DEMO_SEEDS=1` is set.
