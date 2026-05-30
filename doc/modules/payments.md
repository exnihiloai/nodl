# Payments (Stripe)

Source files:
- [`app/controllers/payments_controller.rb`](../../app/controllers/payments_controller.rb)

Test file: [`test/integration/payments_stripe_integration_test.rb`](../../test/integration/payments_stripe_integration_test.rb)

## Overview

Stripe Checkout placeholder. The integration creates a hosted Checkout Session and redirects the user to Stripe. Post-payment fulfillment is handled via webhook. No subscription management UI exists yet — Stripe fields (`stripe_customer_id`, `stripe_subscription_id`) on `Workspace` are stored but not populated by the current code.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | Yes (for checkout) | — | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | Yes (for webhook) | — | Stripe webhook signing secret |
| `STRIPE_PRICE_ID` | No | — | Use a pre-existing Stripe price |
| `STRIPE_PRODUCT_NAME` | No | `"Nodl Starter Plan"` | Product name for ad-hoc price |
| `STRIPE_DEFAULT_AMOUNT` | No | `1900` | Amount in cents for ad-hoc price |
| `STRIPE_CURRENCY` | No | `usd` | Currency code |

## Authentication Boundaries

| Route | Auth required | Notes |
|---|---|---|
| `GET /payments` | No | Public pricing/info page; reads auth state to personalise UI |
| `POST /payments/checkout` | Yes (`authenticate_user!`) | Redirects to login if not signed in |
| `GET /payments/success` | Yes (`authenticate_user!`) | |
| `GET /payments/cancel` | Yes (`authenticate_user!`) | |
| `POST /payments/webhook` | No | CSRF skipped; authentication via Stripe signature only — **do not add `authenticate_user!`** as it would break webhook delivery |

## Checkout Flow

`POST /payments/checkout` — authenticated users only.

1. Guards: if `STRIPE_SECRET_KEY` is absent, redirects back to `/payments` with alert.
2. Builds a `line_items` entry: uses `STRIPE_PRICE_ID` if set, otherwise constructs `price_data` from env vars.
3. Calls `Stripe::Checkout::Session.create` with `mode: "payment"`, `automatic_tax: { enabled: true }`, metadata containing `user_id` and `workspace_id`.
4. Redirects to `checkout_session.url` with `allow_other_host: true, status: :see_other`.
5. On `Stripe::StripeError` or missing URL, redirects to `/payments` with alert.

Success URL: `/payments/success?session_id={CHECKOUT_SESSION_ID}`
Cancel URL: `/payments/cancel`

## Webhook

`POST /payments/webhook` — CSRF protection skipped, Stripe signature validated instead.

1. Returns 503 if `STRIPE_WEBHOOK_SECRET` is missing.
2. Returns 400 if `Stripe-Signature` header is absent.
3. Calls `Stripe::Webhook.construct_event(payload, signature, secret)`.
4. Logs `checkout.session.completed` events (no fulfillment logic yet — **TODO**: implement subscription activation).
5. Returns `{ received: true }` on success.
6. Returns 400 on `JSON::ParserError` or `Stripe::SignatureVerificationError`.

## Test Coverage

Integration tests in [`test/integration/payments_stripe_integration_test.rb`](../../test/integration/payments_stripe_integration_test.rb) cover:
- Checkout button visibility based on `STRIPE_SECRET_KEY` presence
- Redirect to Stripe session URL
- Missing key guard
- Missing session URL guard
- Auth guard (checkout requires login)
- Webhook 503 on missing secret
- Webhook 400 on missing signature
- Webhook success on valid `checkout.session.completed`
- Webhook 400 on invalid signature

All Stripe API calls are stubbed with `mocha`. No external network calls in tests.
