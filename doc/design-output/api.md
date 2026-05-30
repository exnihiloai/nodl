# HTTP API / Routes

All routes are defined in [`config/routes.rb`](../config/routes.rb). The application renders HTML (SSR) for browser clients. JSON responses are limited to health/status endpoints and the Stripe webhook.

## Public Routes (no auth required)

| Method | Path | Controller#Action | Notes |
|---|---|---|---|
| GET | `/` | `pages#home` | Landing page; loads current_workspace if signed in |
| GET | `/about` | `pages#about` | Static marketing page |
| GET | `/try-now` | `pages#try_now` | Static marketing page |
| GET | `/healthz` | `pages#healthz` | Returns `{ status: "ok" }` JSON |
| GET | `/readyz` | `pages#readyz` | DB connectivity check; JSON or HTML partial |
| GET | `/up` | `rails/health#show` | Rails built-in health check |
| GET | `/login` | `sessions#new` | Login form |
| POST | `/login` | `sessions#create` | Authenticate; sets `session[:user_id]` |
| DELETE/POST | `/logout` | `sessions#destroy` | Clears session |
| GET | `/register` | `registrations#new` | Registration form |
| POST | `/register` | `registrations#create` | Create user + workspace + membership |

## Authenticated Routes

| Method | Path | Controller#Action | Notes |
|---|---|---|---|
| GET | `/dashboard` | `dashboard#show` | Requires login |
| POST | `/workspaces/:id/switch` | `workspaces#switch` | Switch active workspace |
| GET | `/payments` | `payments#show` | Pricing/checkout page (public but reads auth state) |
| POST | `/payments/checkout` | `payments#checkout` | Requires login; redirects to Stripe |
| GET | `/payments/success` | `payments#success` | Requires login |
| GET | `/payments/cancel` | `payments#cancel` | Requires login |
| POST | `/payments/webhook` | `payments#webhook` | CSRF skipped; validated by Stripe signature |

## Admin Routes (require `admin` role)

Namespace prefix: `/admin`

| Method | Path | Controller#Action | Notes |
|---|---|---|---|
| GET | `/admin/users` | `admin/users#index` | List all users |
| GET | `/admin/users/new` | `admin/users#new` | New user form |
| POST | `/admin/users` | `admin/users#create` | Create user + workspace + audit event |
| GET | `/admin/users/:id` | `admin/users#show` | User detail with audit log |
| PATCH | `/admin/users/:id/update_email` | `admin/users#update_email` | |
| PATCH | `/admin/users/:id/update_role` | `admin/users#update_role` | |
| PATCH | `/admin/users/:id/update_password` | `admin/users#update_password` | |
| PATCH | `/admin/users/:id/update_usage` | `admin/users#update_usage` | Updates workspace usage_limits |
| POST | `/admin/users/:id/generate_password` | `admin/users#generate_password` | Generates random password |
| POST | `/admin/users/:id/deactivate` | `admin/users#deactivate` | Sets active=false |
| POST | `/admin/users/:id/reactivate` | `admin/users#reactivate` | Sets active=true |

All admin mutation endpoints respond to both Turbo Stream and HTML formats. Turbo Stream responses replace the relevant partial in place; HTML responses redirect with flash.

## Health Endpoints

### GET /healthz
Always returns HTTP 200.
```json
{ "status": "ok" }
```

### GET /readyz
Checks `ActiveRecord::Base.connection.active?`.
- HTTP 200: `{ "status": "ok" }`
- HTTP 503: `{ "status": "error" }`

Accepts `Accept: text/html` to render `shared/_status_check` partial instead.

## Stripe Webhook

### POST /payments/webhook

CSRF protection is disabled for this endpoint. Stripe signature validation is mandatory.

Required headers:
- `Stripe-Signature` — must be present
- `Content-Type: application/json`

Required env var: `STRIPE_WEBHOOK_SECRET`

Response codes:
| Condition | Status |
|---|---|
| Missing webhook secret | 503 Service Unavailable |
| Missing Stripe-Signature header | 400 Bad Request |
| Invalid signature | 400 Bad Request |
| Valid event | 200 `{ "received": true }` |

Currently handles `checkout.session.completed` (logs session ID). All other event types are acknowledged and ignored.

Source: [`app/controllers/payments_controller.rb`](../app/controllers/payments_controller.rb)
