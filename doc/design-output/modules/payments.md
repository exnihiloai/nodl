# Payments (Stripe)

Source files:
- [`app/controllers/payments_controller.rb`](../../app/controllers/payments_controller.rb)

Test file: [`test/integration/payments_stripe_integration_test.rb`](../../test/integration/payments_stripe_integration_test.rb)

## Overview

Stripe Checkout subscription flow. The pricing page lets users choose a plan, region/currency, and billing interval, then redirects to hosted Stripe Checkout. Post-payment entitlement activation is handled via webhook.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | Yes (for checkout) | — | Stripe secret key |
| `STRIPE_WEBHOOK_SECRET` | Yes (for webhook) | — | Stripe webhook signing secret |
| `STRIPE_STARTER_PRICE_ID_EUR` | No | — | Starter monthly price for EU (€29) |
| `STRIPE_STARTER_PRICE_ID_USD` | No | — | Starter monthly price for International ($39) |
| `STRIPE_BUSINESS_PRICE_ID_EUR` | No | — | Business monthly price for EU (€99) |
| `STRIPE_BUSINESS_PRICE_ID_USD` | No | — | Business monthly price for International ($129) |
| `STRIPE_STARTER_ANNUAL_PRICE_ID_EUR` | No | — | Starter annual price for EU (€290, 2 months free) |
| `STRIPE_STARTER_ANNUAL_PRICE_ID_USD` | No | — | Starter annual price for International ($390, 2 months free) |
| `STRIPE_BUSINESS_ANNUAL_PRICE_ID_EUR` | No | — | Business annual price for EU (€990, 2 months free) |
| `STRIPE_BUSINESS_ANNUAL_PRICE_ID_USD` | No | — | Business annual price for International ($1,290, 2 months free) |
| `STRIPE_PRICE_ID` | No | — | Legacy Starter fallback when regional IDs are unset |
| `STRIPE_STARTER_PRICE_ID` | No | — | Deprecated alias for Starter |
| `STRIPE_BUSINESS_PRICE_ID` | No | — | Deprecated alias for Business |
| `STRIPE_PRODUCT_NAME` | No | `"Nodl Starter Plan"` | Legacy success-page label |
| `STRIPE_DEFAULT_AMOUNT` | No | `3900` | Deprecated |
| `STRIPE_CURRENCY` | No | `usd` | Deprecated |

Launch prices are locked in `doc/design-input/domain/billing-plans-and-entitlements.md` §11.3.

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
2. Normalizes `plan`, `region`, and `interval` from the form and resolves the active entitlement version.
3. Builds a subscription `line_items` entry from `BillingPriceCatalog`: uses a fixed Stripe Price ID when configured, otherwise falls back to inline `price_data` from the local catalog.
4. Calls `Stripe::Checkout::Session.create` with `mode: "subscription"`, `automatic_tax: { enabled: true }`, customer email, workspace reference, and metadata containing `user_id`, `workspace_id`, `plan_version_id`, `plan_code`, `billing_region`, `billing_interval`, `currency`, and `amount_cents`.
5. Redirects to `checkout_session.url` with `allow_other_host: true, status: :see_other`.
6. On `Stripe::StripeError` or missing URL, redirects to `/payments` with alert.

Success URL: `/payments/success?session_id={CHECKOUT_SESSION_ID}`
Cancel URL: `/payments/cancel`

## Webhook

`POST /payments/webhook` — CSRF protection skipped, Stripe signature validated instead.

1. Returns 503 if `STRIPE_WEBHOOK_SECRET` is missing.
2. Returns 400 if `Stripe-Signature` header is absent.
3. Calls `Stripe::Webhook.construct_event(payload, signature, secret)`.
4. Deduplicates event IDs and processes `checkout.session.completed` by granting the metadata plan version to the workspace.
5. Returns `{ received: true }` on success.
6. Returns 400 on `JSON::ParserError` or `Stripe::SignatureVerificationError`.

## Test Coverage

Integration tests in [`test/integration/payments_stripe_integration_test.rb`](../../test/integration/payments_stripe_integration_test.rb) cover:
- Pricing page plan visibility based on `STRIPE_SECRET_KEY` presence
- Redirect to Stripe session URL with fixed Stripe Price IDs
- Inline catalog `price_data` fallback when fixed Stripe Price IDs are absent
- Missing key guard
- Missing session URL guard
- Auth guard (checkout requires login)
- Webhook 503 on missing secret
- Webhook 400 on missing signature
- Webhook success on valid `checkout.session.completed`
- Webhook 400 on invalid signature

All Stripe API calls are stubbed with `mocha`. No external network calls in tests.
