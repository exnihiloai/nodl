# ADR 002: Solid Cache / Queue / Cable (DB-backed) Instead of Redis

Date: 2026-02-21
Status: Accepted

## Context

Background job processing, caching, and WebSocket pub/sub are standard SaaS requirements. The common Rails stack uses Redis for all three. This boilerplate targets single-server deployments and developer simplicity.

## Decision

Use the Rails 8 Solid stack:
- `solid_cache` — DB-backed `Rails.cache`
- `solid_queue` — DB-backed Active Job backend
- `solid_cable` — DB-backed Action Cable backend

Solid Queue runs inside the Puma process via `plugin :solid_queue` (controlled by `SOLID_QUEUE_IN_PUMA` env var). On multi-server deployments, it can be split into a dedicated `bin/jobs` process.

## Rationale

- Eliminates Redis as an infrastructure dependency — reduces operational complexity for a boilerplate.
- PostgreSQL is already required; reusing it for cache/queue/cable avoids a second stateful service.
- Rails 8 ships Solid stack as the default — aligns with upstream conventions.
- Acceptable throughput for a single-server SaaS starter.

## Consequences

- At high job/message volume, DB-backed queue/cable will be slower than Redis. Implementors should migrate to Sidekiq + Redis when needed.
- Four separate PostgreSQL databases in production (`primary`, `cache`, `queue`, `cable`) — slightly more complex DB setup than a single database.
- Recurring job cleanup configured in [`config/recurring.yml`](../../config/recurring.yml): `SolidQueue::Job.clear_finished_in_batches` every hour.
