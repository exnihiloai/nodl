# Admin Namespace

Source files:
- [`app/controllers/admin/users_controller.rb`](../../app/controllers/admin/users_controller.rb)
- [`app/models/admin_audit_event.rb`](../../app/models/admin_audit_event.rb)
- [`app/views/admin/users/`](../../app/views/admin/users/)

## Access Control

All actions in `Admin::UsersController` require:
1. `authenticate_user!` — must be signed in
2. `require_admin!` — `User#role` must be `admin`

Unauthorised users are redirected to `/dashboard`.

## User Management Actions

| Action | Route | Description |
|---|---|---|
| `index` | GET /admin/users | Lists all users with memberships/workspaces eagerly loaded, ordered by `created_at DESC` |
| `show` | GET /admin/users/:id | Detail view: primary workspace, last 25 audit events |
| `new` | GET /admin/users/new | Create user form |
| `create` | POST /admin/users | Create user + workspace + membership in transaction; audit logged |
| `update_email` | PATCH /admin/users/:id/update_email | Update user email; audit logged |
| `update_role` | PATCH /admin/users/:id/update_role | Change user role; audit logged |
| `update_password` | PATCH /admin/users/:id/update_password | Set explicit password (min 8 chars) |
| `generate_password` | POST /admin/users/:id/generate_password | Generate random `base58(14)` password; displayed once |
| `deactivate` | POST /admin/users/:id/deactivate | Set `active=false`; audit logged |
| `reactivate` | POST /admin/users/:id/reactivate | Set `active=true`; audit logged |
| `update_usage` | PATCH /admin/users/:id/update_usage | Update `usage_limits` on primary workspace; audit logged |

## Turbo Stream Responses

Each mutation action responds to both `turbo_stream` and `html` formats. On Turbo Stream, the relevant partial is replaced in-place (e.g. `email_section`, `role_section`, `password_section`, `lifecycle_section`, `usage_section`). On HTML fallback, a redirect with flash is issued.

View partials:
- `_email_section.html.erb`
- `_role_section.html.erb`
- `_password_section.html.erb`
- `_lifecycle_section.html.erb`
- `_usage_section.html.erb`
- `_create_result.html.erb` — shown after user creation (includes generated password if applicable)

## Audit Events

Every state-changing admin action calls the private `audit!` method:

```ruby
AdminAuditEvent.create!(
  user: target_user,        # user being modified
  acting_admin: current_user,
  action: "update_email",
  before_state: { email: old_email },
  after_state:  { email: new_email }
)
```

`before_state` and `after_state` are stored as `jsonb`. The `action` field uses snake_case string identifiers.

Defined action strings: `create_user`, `update_email`, `update_role`, `update_password`, `generate_password`, `deactivate`, `reactivate`, `update_usage_limits`.

The user detail page shows the 25 most recent audit events (`recent_first` scope).
