# Authentication

Source files:
- [`app/controllers/sessions_controller.rb`](../../app/controllers/sessions_controller.rb)
- [`app/controllers/registrations_controller.rb`](../../app/controllers/registrations_controller.rb)
- [`app/controllers/application_controller.rb`](../../app/controllers/application_controller.rb)
- [`app/models/user.rb`](../../app/models/user.rb)

## Mechanism

Session-based authentication using Rails encrypted cookie sessions. No JWT or token-based auth.

`session[:user_id]` stores the authenticated user's primary key. `current_user` in `ApplicationController` resolves this lazily via `User.find_by(id: user_id)`.

## Registration Flow

`POST /register` — `RegistrationsController#create`

1. Validates email confirmation match, password confirmation match, password strength (min 8 chars, must contain uppercase + lowercase + digit).
2. Checks uniqueness of email before DB insert.
3. Wraps creation of `User`, `Workspace`, and `Membership` in a single transaction.
4. Default workspace: `usage_limits: { scans: 1000, storage_mb: 1024 }` and `usage_consumption: { scans: 0, storage_mb: 0 }` are set explicitly. `subscription_plan`, `subscription_status`, and `subscription_billing_cycle` are **not** set in the controller — they take their values from database column defaults (`"free"`, `"inactive"`, `"monthly"`).
5. Sets `session[:user_id]` and `session[:current_workspace_id]` immediately — user is logged in on registration.
6. Redirects to `/dashboard`.

## Login Flow

`POST /login` — `SessionsController#create`

1. Normalises email (downcase + strip).
2. Checks login throttle before attempting auth (fail-open: throttle errors are silently ignored).
3. Looks up user by email, calls `user.authenticate(password)` (bcrypt), verifies `user.active?`.
4. On success: `reset_session` (regenerates session ID), sets `session[:user_id]` and `session[:current_workspace_id]`, clears failed-login counters, updates `last_login_at`, redirects to `/dashboard`.
5. On failure: increments failed-login counter, re-renders form with generic "Invalid credentials." (no user enumeration).

## Logout

`DELETE /logout` or `POST /logout` — `SessionsController#destroy`

Calls `reset_session`. Redirects to `/`.

## Login Throttling

Implemented entirely in `SessionsController` using `Rails.cache`.

| Constant | Value |
|---|---|
| `LOGIN_ATTEMPT_WINDOW` | 10 minutes |
| `LOGIN_BLOCK_WINDOW` | 15 minutes |
| `MAX_LOGIN_ATTEMPTS` | 10 |

Cache keys use `SHA256(email|ip)` to prevent cache key enumeration. After 10 failures within 10 minutes, the account+IP combination is blocked for 15 minutes. The blocked state is stored as a timestamp; on each request the code checks `blocked_until > Time.current`.

Any cache errors (e.g. cache unavailable) fail open — throttle is bypassed rather than blocking all logins.

## Controller Helpers

Defined in [`ApplicationController`](../../app/controllers/application_controller.rb), available as `helper_method` in views:

| Method | Behaviour |
|---|---|
| `current_user` | Memoised; returns `User` or `nil` |
| `user_signed_in?` | `current_user.present?` |
| `authenticate_user!` | Redirects to `/login` if not signed in |
| `require_admin!` | Redirects to `/dashboard` if not admin role |

## Password Security

- Passwords hashed with bcrypt via `has_secure_password` (`gem "bcrypt", "~> 3.1.7"`).
- Email normalised with `normalizes :email` (Rails 7.1+ normalizer) — strip + downcase applied at the model layer before save.
- Admin-generated passwords use `SecureRandom.base58(14)`.
