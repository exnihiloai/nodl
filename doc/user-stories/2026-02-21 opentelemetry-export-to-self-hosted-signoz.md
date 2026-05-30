## User Story: OpenTelemetry export to self-hosted SigNoz

**As a** platform engineer running a self-hosted SigNoz instance,
**I want to** configure OTEL export via environment variables,
**so that** application logs and minimal telemetry are sent automatically without code changes per environment.

### Background
- We need observability in a self-hosted SigNoz setup, not SaaS vendor defaults.
- Configuration must be environment-driven to support local/dev/staging/prod parity.
- Missing or invalid OTEL config must not crash app boot or request handling.

### In Scope
- Support the following env vars:
  - `OTEL_INGEST_TOKEN`
  - `OTEL_EXPORTER_OTLP_ENDPOINT`
  - `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`
  - `OTEL_SERVICE_NAME`
- Export Rails logs to OTLP logs endpoint (with token auth).
- Export minimal telemetry (baseline traces/metrics suitable for service health visibility).
- Define sane defaults/fallback behavior (e.g., logs endpoint fallback when only base endpoint is set).
- Document setup and troubleshooting in README/developer docs.

### Out of Scope
- Full observability platform rollout (dashboards, alerts, SLO modeling).
- Advanced distributed tracing across external services.

### Acceptance Criteria
- AC-01: When `OTEL_EXPORTER_OTLP_ENDPOINT` is set, app starts and exports minimal telemetry to SigNoz.
- AC-02: When `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` is set, application logs are exported to that endpoint.
- AC-03: When `OTEL_INGEST_TOKEN` is set, exporter attaches token in OTLP auth header as configured by implementation.
- AC-04: `OTEL_SERVICE_NAME` is reflected in emitted telemetry resource attributes.
- AC-05: If OTEL env vars are missing/invalid, app continues operating and logs a clear warning (no boot crash).
- AC-06: Configuration is fully environment-based (no hardcoded endpoint/token in code).

### Technical Notes (Rails)
- Prefer RESTful routes, thin controllers, model validations, and ERB partial reuse.
- Keep tenancy boundaries explicit (workspace/user scoping).
- Keep interactions server-rendered; use Turbo/Stimulus only where needed.
- Initialize OTEL in application boot path with guard rails for disabled/misconfigured exporter.
- Keep outbound OTEL network behavior non-blocking for request path as far as practical.

### Testing
- Integration tests for config resolution and graceful fallback behavior.
- Tests for auth header/token propagation to OTLP exporter configuration.
- Tests that telemetry/log export setup does not raise during app boot when endpoints are absent.
- Optional smoke test against local mock OTLP receiver in containerized environment.

### Definition of Done
- All acceptance criteria implemented.
- Tests added/updated and passing with `make test`.
- Documentation updated where relevant.
- No known regressions.
