# Multi-Tenancy

Source files:
- [`app/models/workspace.rb`](../../app/models/workspace.rb)
- [`app/models/membership.rb`](../../app/models/membership.rb)
- [`app/controllers/application_controller.rb`](../../app/controllers/application_controller.rb)
- [`app/controllers/workspaces_controller.rb`](../../app/controllers/workspaces_controller.rb)
- [`app/controllers/dashboard_controller.rb`](../../app/controllers/dashboard_controller.rb)

## Model

A `User` belongs to one or more `Workspace` records via the `Membership` join table.

```
User  1──< Membership >──1  Workspace
```

`Membership` carries its own `role` enum (distinct from the global `User.role`):

| Value | Integer |
|---|---|
| owner | 0 |
| admin | 1 |
| member | 2 (default) |

A user can hold only one membership per workspace (unique index on `user_id + workspace_id`).

## Current Workspace Resolution

`current_workspace` in `ApplicationController`:

1. Returns `nil` if no authenticated user.
2. Tries `current_user.workspaces.find_by(id: session[:current_workspace_id])`.
3. Falls back to the user's oldest membership via `current_user.workspaces.order("memberships.created_at ASC").first` (`.first` implies `LIMIT 1` at the ORM level). Note: during login, `SessionsController#create` uses `.pick(:id)` on the same ordered relation — functionally equivalent but a different code path.
4. Writes the resolved workspace ID back to `session[:current_workspace_id]`.

The resolved workspace is available as a helper in all views.

## Dashboard Context

`GET /dashboard` — `DashboardController#show` (requires authentication).

- Sets `@workspace = current_workspace` for the active tenant context.
- Sets `@memberships = current_user.memberships.includes(:workspace).order(:created_at)` so the dashboard can render workspace-switching context from the user's memberships.

## Switching Workspaces

`POST /workspaces/:id/switch` — `WorkspacesController#switch`

Scoped to `current_user.workspaces` — users cannot switch to a workspace they do not belong to. Sets `session[:current_workspace_id]`, redirects to dashboard.

## Workspace Creation

Created atomically with user on registration (`RegistrationsController#create`) and admin-created users (`Admin::UsersController#create`). The creating user receives `role: :owner` on the membership.

Slug generation differs by creation path:

- **Registration** (`RegistrationsController#create`): slug is explicitly provided as `SecureRandom.alphanumeric(10).downcase` — a 10-character random lowercase alphanumeric string. The `ensure_slug` callback is not triggered because the slug is already present.
- **All other paths** (e.g. admin-created workspaces where slug is left blank): the `ensure_slug` `before_validation` callback fires and generates `"<name-parameterized>-<SecureRandom.alphanumeric(6).downcase>"` (name-derived prefix + 6-char random suffix).

## Usage Tracking

`usage_limits` and `usage_consumption` are `jsonb` columns on `Workspace`. Keys are application-defined strings (e.g. `"scans"`, `"storage_mb"`).

Accessor methods on `Workspace`:
- `usage_limit_for(key, default_value)` — reads limit or returns default
- `usage_consumed_for(key)` — reads consumption or returns 0

Admins can update limits per-user via `PATCH /admin/users/:id/update_usage`.

Seed defaults: `{ scans: 1000, storage_mb: 1024 }`.
