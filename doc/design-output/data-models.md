# Data Models

Source of truth: [`db/schema.rb`](../db/schema.rb) (ActiveRecord 8.1, schema version `2026_05_31_090100`).

## Entity Relationship Summary

```
User ──< Membership >── Workspace
User ──< AdminAuditEvent
User (acting_admin) ──< AdminAuditEvent
Workspace ──< RecordingSession ── Document
Workspace ──< TransformerProfile
```

## users

Migration: [`db/migrate/20260221130244_create_users.rb`](../db/migrate/20260221130244_create_users.rb)
Model: [`app/models/user.rb`](../app/models/user.rb)

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | bigint | PK | auto |
| email | string | NOT NULL, UNIQUE | normalised to lowercase/stripped |
| password_digest | string | NOT NULL | bcrypt via `has_secure_password` |
| role | integer | NOT NULL, default 0 | enum: `user=0`, `admin=1` |
| active | boolean | NOT NULL, default true | soft-disable flag |
| last_login_at | datetime | nullable | updated on successful login |
| preferred_language | string | NOT NULL, default "en" | allowed: `en`, `de` |
| created_at / updated_at | datetime | NOT NULL | |

Associations:
- `has_many :memberships, dependent: :destroy`
- `has_many :workspaces, through: :memberships`
- `has_many :admin_audit_events, dependent: :destroy`
- `has_many :acting_admin_audit_events, class_name: "AdminAuditEvent", foreign_key: :acting_admin_id, dependent: :destroy` — **deleting an admin user cascades and destroys all audit events where they were the acting admin**, which removes part of the audit trail.

Scopes: `active_only` — `where(active: true)`

Instance methods: `display_role` — returns capitalised role string.

## workspaces

Migration: [`db/migrate/20260221130245_create_workspaces.rb`](../db/migrate/20260221130245_create_workspaces.rb)
Model: [`app/models/workspace.rb`](../app/models/workspace.rb)

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | bigint | PK | auto |
| name | string | NOT NULL | normalised (strip) |
| slug | string | NOT NULL, UNIQUE | auto-generated; parameterised |
| subscription_status | string | NOT NULL, default "inactive" | e.g. `inactive`, `active` |
| subscription_plan | string | NOT NULL, default "free" | e.g. `free`, `pro` |
| subscription_billing_cycle | string | NOT NULL, default "monthly" | |
| stripe_customer_id | string | nullable | |
| stripe_subscription_id | string | nullable | |
| usage_limits | jsonb | NOT NULL, default {} | arbitrary key/value limits |
| usage_consumption | jsonb | NOT NULL, default {} | arbitrary key/value counters |
| created_at / updated_at | datetime | NOT NULL | |

Associations: `has_many :memberships, dependent: :destroy`, `has_many :users, through: :memberships`, `has_many :recording_sessions`, `has_many :documents`, `has_many :transformer_profiles`

Before validation: `ensure_slug` — generates `"<name-slug>-<6-char-random>"` if blank.

Instance methods:
- `usage_limit_for(key, default_value)` — reads from `usage_limits` jsonb
- `usage_consumed_for(key)` — reads from `usage_consumption` jsonb

Seed defaults for `usage_limits`: `{ scans: 1000, storage_mb: 1024 }`.

## memberships

Migration: [`db/migrate/20260221130246_create_memberships.rb`](../db/migrate/20260221130246_create_memberships.rb)
Model: [`app/models/membership.rb`](../app/models/membership.rb)

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | bigint | PK | |
| user_id | bigint | NOT NULL, FK → users | |
| workspace_id | bigint | NOT NULL, FK → workspaces | |
| role | integer | NOT NULL, default 2 | enum: `owner=0`, `admin=1`, `member=2` |
| created_at / updated_at | datetime | NOT NULL | |

Unique index on `(user_id, workspace_id)` — one membership per user per workspace.

## admin_audit_events

Migration: [`db/migrate/20260221130252_create_admin_audit_events.rb`](../db/migrate/20260221130252_create_admin_audit_events.rb)
Model: [`app/models/admin_audit_event.rb`](../app/models/admin_audit_event.rb)

| Column | Type | Constraints | Notes |
|---|---|---|---|
| id | bigint | PK | |
| user_id | bigint | NOT NULL, FK → users | the user being acted upon |
| acting_admin_id | bigint | NOT NULL, FK → users | the admin performing the action |
| action | string | NOT NULL | e.g. `create_user`, `update_email`, `deactivate` |
| before_state | jsonb | nullable | snapshot before change |
| after_state | jsonb | nullable | snapshot after change |
| created_at / updated_at | datetime | NOT NULL | |

Scope: `recent_first` — `order(created_at: :desc)`.

## Migrations

All migrations are in [`db/migrate/`](../db/migrate/). Prefer reversible migrations. Never edit historical migrations. Run `bin/rails db:migrate` and commit the updated `db/schema.rb`.

## Audio Dashboard Models

`transformer_profiles` stores workspace-local transformer catalog entries. Each workspace has one default profile for the filesystem transformer handle `default`.

`recording_sessions` stores tenant-scoped dashboard processing state, including creator, status, source kind, transformer handle, transcript text, failure message, and processing timestamps. It also stores the structured transcript (`transcript_segments` jsonb: per-segment start/end/speaker/text) and the precomputed waveform (`waveform_peaks` jsonb + `audio_duration` float) used by the audio player. Original and normalized audio files are attached through Active Storage.

`documents` stores generated Markdown output for a completed recording session. Document versioning and editing are not implemented yet.
