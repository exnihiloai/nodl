# ADR 001: Session-Based Authentication

Date: 2026-02-21
Status: Accepted

## Context

The application is a server-rendered SaaS boilerplate. Authentication must be simple, secure by default, and require no additional infrastructure.

## Decision

Use Rails encrypted cookie sessions (`session[:user_id]`) with `has_secure_password` (bcrypt). No JWT, OAuth, or external auth provider.

## Rationale

- Zero additional infrastructure — sessions are stored in the encrypted cookie; no Redis or DB table required.
- Rails `reset_session` on login prevents session fixation.
- `has_secure_password` provides bcrypt hashing with a well-tested API.
- Login throttling via `Rails.cache` adds brute-force protection without an external rate-limiter.
- Fits the HTML-first, no-SPA design (no need for stateless token auth across separate front/back ends).

## Consequences

- Sessions are stateless from the server's perspective — no built-in forced logout of all sessions (e.g. on password change). Acceptable for a boilerplate; implementors can add a session invalidation token column if needed.
- Cookie size limit applies — only `user_id` and `current_workspace_id` are stored.
