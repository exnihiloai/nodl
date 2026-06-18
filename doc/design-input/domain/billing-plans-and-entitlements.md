# Billing Plans and Entitlements — Design Document

> Status: **Proposed** · Date: 2026-06-18 · Type: design-input
>
> This document captures the planned foundation for Nodl pricing, free trials, paid subscriptions, grandfathered private access, versioned plan limits, and administrator control.

## 1. Summary

Nodl needs a billing and entitlement foundation before pricing walls, paid tiers, or Stripe subscription fulfillment are implemented. The current app has early payment scaffolding and hard-coded plan limits, but the intended product behavior requires a more durable model:

- Existing workspaces receive operator-granted **Private Access**.
- New users start on a no-card **Free Trial**.
- Paid customers subscribe to **Starter** or **Business**.
- Paid plan limits are monthly and must be fair to existing subscribers when commercial packaging changes.
- Usage gates must be based on append-only usage history, not current row counts, because deleting content must not reset trial counters.

The foundation should separate plan catalog definitions, versioned plan packages, workspace entitlements, usage events, and Stripe subscription state.

---

## 2. Goals

- Support four plan codes: `manual`, `trial`, `starter`, and `business`.
- Show `manual` users as **Private Access** in administrator-facing UI.
- Migrate all existing workspaces to `manual` / Private Access.
- Default newly created workspaces to `trial` once the billing foundation is active.
- Use Stripe Billing subscriptions for paid plans, not one-time payments.
- Version paid plan limits so existing subscribers keep the limits they purchased.
- Track usage through append-only events so usage is not reduced by deleting recordings, documents, formats, exports, or downloads.
- Enforce gates centrally through an entitlement policy rather than scattered controller constants.
- Provide administrator tools for viewing and changing workspace entitlements.
- Preserve auditability for every entitlement-changing action.

---

## 3. Non-goals

- Finalizing exact Starter vs Business feature distinctions. Those limits may be defined later and may change over time.
- Building the full billing admin UI in one step. A phased implementation is expected.
- Building a custom payment form. Stripe Checkout remains the desired payment frontend.
- Implementing Stripe Connect, marketplaces, invoicing, or usage-based billing in phase 1.
- Locking users out of already delivered content during an in-progress recording or processing flow.

---

## 4. Locked design decisions

| # | Decision | Rationale |
|---|---|---|
| **D1** | **Workspace-scoped billing** | Nodl tenancy is workspace-based. Plans and entitlements attach to `Workspace`, not individual `User` records. |
| **D2** | **Four plan codes**: `manual`, `trial`, `starter`, `business` | Covers grandfathered/private access, no-card trial, and two paid commercial tiers. |
| **D3** | **Manual plan is called Private Access in admin UI** | The internal code describes the grant mechanism; the UI label describes the operator-facing meaning. |
| **D4** | **All existing workspaces migrate to `manual`** | Avoids accidentally locking out known existing users who currently live under hard-coded limits. |
| **D5** | **New workspaces default to `trial` after launch** | Keeps signup zero-friction while making trial usage explicit and enforceable. |
| **D6** | **Paid limits are monthly** | Starter and Business usage should reset monthly, aligned to the subscription billing period. |
| **D7** | **Trial limits are lifetime / total-ever** | The trial spec says deleting content does not reset counters. Trial usage is a one-time allowance. |
| **D8** | **Grace period is 14 days** | Past-due paid customers should not be locked immediately after payment failure. |
| **D9** | **Plan limit changes create new plan versions** | Existing subscribers keep the package they bought; new subscribers can receive the changed package. |
| **D10** | **Store workspace entitlement snapshots** | A workspace should retain the exact limits it was granted even if catalog rows are later retired or edited. |
| **D11** | **Stripe Prices map to commercial plan versions** | A materially different paid package should use a distinct Stripe Price ID. |
| **D12** | **Active and retired plan versions are immutable** | Prevents accidental retroactive limit changes. Editable changes happen only on draft versions. |
| **D13** | **Usage is append-only** | Deleting a recording, format, document, or attachment must not reduce historical usage. |
| **D14** | **Stripe is payment authority; Rails is entitlement authority** | Stripe determines subscription/payment state. Nodl determines feature access, local usage, and product gates. |
| **D15** | **Launch pricing is regional (EU vs International)** | Same plan entitlements; checkout uses a region-specific Stripe Price. EU customers see EUR; International (US-led) customers see USD. |

---

## 5. Plan taxonomy

### 5.1 Internal codes and display names

| Internal code | Display name | Source | Stripe required? | Intended use |
|---|---|---|---|---|
| `manual` | Private Access | Operator/admin | No | Founder accounts, spouse/family accounts, beta users, partners, support grants, special cases |
| `trial` | Free Trial | Signup | No | No-card product trial for new workspaces |
| `starter` | Starter | Stripe | Yes | Paid entry plan |
| `business` | Business | Stripe | Yes | Paid higher-tier plan |

Internal plan codes should be stable. Public names may change later without changing stored plan codes.

### 5.2 Manual / Private Access

Manual access is a first-class entitlement source, not a hack around billing.

Manual workspaces:

- Are not Stripe subscribers by default.
- Are not trial users.
- Should not be downgraded because Stripe customer or subscription IDs are absent.
- May have unlimited limits or an explicit custom snapshot.
- Should require an audit reason when granted or changed.
- May optionally have an expiration date for temporary grants.

---

## 6. Versioned plan model

Pricing and commercial packaging may change. For example, Business might include 100 recordings today and 50 recordings later while existing Business subscribers keep 100.

The model should distinguish:

| Concept | Meaning |
|---|---|
| **Plan** | Stable product family: Trial, Starter, Business, Manual |
| **Plan version** | A dated/versioned package of limits and capabilities |
| **Workspace entitlement** | The specific access package granted to one workspace |
| **Limits snapshot** | The exact limits granted to a workspace at assignment time |

### 6.1 Example versions

```text
business_2026_06_v1
  recordings_per_month: 100
  stripe_price_id: price_business_100_recordings

business_2026_08_v2
  recordings_per_month: 50
  stripe_price_id: price_business_50_recordings
```

Existing subscribers assigned to `business_2026_06_v1` keep 100 monthly recordings unless explicitly migrated. New subscribers can be routed to `business_2026_08_v2`.

### 6.2 Version lifecycle

```text
draft -> active -> retired
```

| State | Meaning | Editable? | Sellable? |
|---|---|---|---|
| `draft` | Being prepared | Yes | No |
| `active` | Available for new assignment/subscription | No, except safe metadata | Yes |
| `retired` | Hidden from new purchases, valid for existing workspaces | No, except safe metadata | No |

Changing sellable limits creates a new draft version. It does not mutate an active or retired version.

---

## 7. Entitlement resolution

All product gates should use one policy object or service that answers:

```text
Can this workspace perform this action right now?
```

Controllers, models, and views should not independently interpret plan codes, Stripe statuses, or raw limit constants.

Recommended precedence:

```text
workspace override
  > workspace entitlement limits snapshot
  > plan version limits
  > system fallback
```

The entitlement policy should return a structured result, not just true/false:

```text
allowed: true/false
reason: :limit_reached, :trial_expired, :past_due_grace, :not_included, ...
usage: consumed/current period
limit: configured limit
upgrade_target: starter/business when relevant
```

This lets the UI render the correct wall without duplicating billing logic.

---

## 8. Extensible limit model

Plan versions and workspace entitlement snapshots should store limits as structured capability definitions, not as a fixed set of hard-coded columns or Ruby methods.

The design must support adding new limit categories later, such as maximum duration per recording or maximum weekly recorded hours, without redesigning the billing system.

### 8.1 Capability keys

Each limit should have a stable capability key:

```text
recordings
custom_formats
exports
original_audio_downloads
integrity_checks
max_recording_duration_seconds
recorded_audio_seconds
```

New capabilities can be added by adding new keys and policy handlers. Existing entitlement snapshots keep the keys and values assigned at the time of grant.

### 8.2 Limit types

The entitlement policy should support several limit types:

| Type | Example | Enforcement style |
|---|---|---|
| `count` | 100 recordings per billing period | Count matching usage events in the active period. |
| `quantity` | 20 recorded hours per week | Sum a numeric quantity, such as audio seconds, from usage events in the active period. |
| `per_action` | Maximum 60 minutes per recording | Check the candidate action itself, using data such as audio duration. |
| `boolean` | Integrity checks included or not included | Allow or deny the capability without a numeric counter. |
| `unlimited` | Private Access recordings | Always allow unless another explicit restriction applies. |

### 8.3 Periods and units

Limits should declare their period and unit explicitly when relevant:

| Field | Examples | Notes |
|---|---|---|
| `period` | `lifetime`, `usage_period`, `week`, `day`, `per_action` | Trial uses lifetime; paid plans use a local monthly usage period even when payment is annual. |
| `unit` | `count`, `seconds`, `bytes` | Required for quantity-style limits. |
| `limit` | `3`, `100`, `72000`, `true`, `unlimited` | Value type depends on limit type. |

Example:

```json
{
  "recordings": {
    "type": "count",
    "limit": 100,
    "period": "usage_period",
    "unit": "count"
  },
  "custom_formats": {
    "type": "count",
    "limit": 10,
    "period": "lifetime",
    "unit": "count"
  },
  "max_recording_duration_seconds": {
    "type": "per_action",
    "limit": 3600,
    "period": "per_action",
    "unit": "seconds"
  },
  "recorded_audio_seconds": {
    "type": "quantity",
    "limit": 72000,
    "period": "week",
    "unit": "seconds"
  },
  "integrity_checks": {
    "type": "boolean",
    "limit": true
  }
}
```

### 8.4 Usage events and quantities

Usage events should be able to carry an optional numeric quantity and unit:

```text
event_kind: recording_created
quantity: 1
unit: count

event_kind: recorded_audio_seconds
quantity: 1840
unit: seconds
```

This keeps simple counters and aggregate usage, such as weekly recorded hours, in the same accounting model.

### 8.5 Implementation rule

Application code should avoid plan-specific methods such as `business_recordings_per_month` or controller-level constants such as `MAX_RECORDINGS`.

Instead, product code should ask the entitlement policy about a capability key:

```text
Can workspace X perform capability Y with candidate quantity Z?
```

The policy owns how to interpret limit type, period, unit, usage history, and entitlement snapshot.

---

## 9. Usage accounting

Usage must be tracked with append-only events.

### 9.1 Why append-only

Trial counters must not reset when users delete content. Counting current database rows is therefore incorrect for trial limits and risky for paid-period usage.

Example:

```text
User creates 3 recordings.
User deletes 2 recordings.
Trial recording usage is still 3/3, not 1/3.
```

### 9.2 Usage event examples

```text
recording_created
custom_format_created
document_exported
original_audio_downloaded
integrity_check_attempted
```

Usage events should include:

- workspace
- user/actor when known
- event kind
- occurred timestamp
- optional subject reference, such as recording/document/profile ID
- optional metadata, such as export format
- billing period identifier when relevant

### 9.3 Trial vs paid periods

| Plan source | Usage period |
|---|---|
| Trial | Lifetime / total-ever |
| Paid subscription | Monthly, aligned to Stripe subscription billing period |
| Manual | Unlimited or explicit configured period/snapshot |

Paid usage should reset at the start of each billing period. Trial usage should not reset.

---

## 10. Trial product behavior

The Free Trial gives users full output quality and no-card signup. Content already created should not be held hostage mid-flow.

### 10.1 Trial allowances

Initial trial limits:

| Capability | Trial allowance |
|---|---|
| Recordings/uploads | 3 total-ever |
| Custom formats | 2 custom formats total-ever, plus the default format |
| Exports | 1 total-ever across Word, PDF, and Markdown |
| Original audio downloads | 1 total-ever |
| Integrity checks | Visible but not enabled |
| Viewing/copying generated content | Always allowed for delivered content |

### 10.2 Gate timing

Walls fire on the **reach forward**:

- Starting a 4th recording or upload.
- Creating a 3rd custom format.
- Attempting a 2nd document export.
- Attempting a 2nd original audio download.
- Attempting to enable or use integrity checks.
- Trial has expired or all allowance has been consumed.

Walls must not fire in the middle of delivering something already promised. A recording accepted for processing should finish and produce its full document.

### 10.3 Paid internal guardrails

Paid tiers should feel effectively unlimited in public pricing copy while retaining internal abuse and cost controls.

Initial internal monthly paid caps:

| Plan | Public-facing recording feel | Internal recordings / billing period | Internal audio hours / billing period |
|---|---|---:|---:|
| Starter | Effectively unlimited | 500 | 100 |
| Business | Effectively unlimited | 2000 | 500 |

The audio-hours cap is represented as `recorded_audio_seconds` with `type: quantity`, `period: usage_period`, and `unit: seconds`.

Usage period note: the local usage window is separate from Stripe payment coverage. For monthly billing, payment coverage and usage period usually align. For annual billing, Stripe payment coverage can be yearly while `usage_period_started_at` / `usage_period_ends_at` rolls monthly.

Current seat note: Nodl does not yet model billable seats. Until seat-level accounting exists, this cap is enforced at workspace entitlement level. When seats are introduced, usage events should carry the seat/member dimension needed to enforce the same cap per seat.

### 10.4 Trial expiry

Trial ends when either condition is met:

- Day 14 is reached.
- All primary usage allowance is consumed, depending on final product copy and gate rules.

Trial expiry should not rely only on page views. A recurring job should mark expired trials and optionally enqueue notifications/audit events.

---

## 11. Paid subscription behavior

Paid plans use Stripe Billing and Checkout Sessions in subscription mode.

### 11.1 Fairness defaults

| Event | Desired behavior |
|---|---|
| Upgrade | Higher limits apply immediately. |
| Downgrade | Lower limits apply at the next billing period, not immediately. |
| Cancellation | Customer keeps access until the paid-through period ends. |
| Payment past due | Customer enters a 14-day grace period before lockout. |
| Plan limit reduction for new customers | Existing subscribers keep their assigned plan version and snapshot. |

### 11.2 Stripe responsibilities

Stripe should handle:

- checkout
- subscription creation
- renewal
- payment retry/dunning
- tax/payment method collection
- customer portal, when added

Nodl should handle:

- local entitlement snapshots
- feature gates
- usage counters
- workspace plan state display
- admin grants/overrides
- product-specific trial behavior

### 11.3 Launch pricing (locked)

Monthly subscription prices at launch. Feature limits are unchanged from section 10.3; only checkout amount and currency differ by region.

| Plan | EU | International (US) |
|---|---:|---:|
| **Starter** | €29 / month | $39 / month |
| **Business** | €99 / month | $129 / month |

Annual subscription prices are **10x monthly** so customers receive 2 months free:

| Plan | EU | International (US) |
|---|---:|---:|
| **Starter** | €290 / year | $390 / year |
| **Business** | €990 / year | $1,290 / year |

Stripe setup:

- Create **eight** recurring Stripe Prices (one per plan × region × billing interval).
- Map them through env vars (see `doc/design-output/modules/payments.md`).
- Checkout selects the Price for the customer's billing region before `Stripe::Checkout::Session.create`.
- Entitlement assignment still keys off the **plan code** (`starter` / `business`), not the Stripe Price ID — EU and International prices grant the same limits snapshot.

Region detection (implementation detail, TBD): prefer explicit customer choice or billing-country signal over IP-only geolocation.

### 11.4 Webhook requirements

Stripe webhooks must be idempotent. Repeated Stripe event delivery must not double-apply entitlement changes or duplicate usage.

Implementation should store processed Stripe event IDs or otherwise make every webhook transition safe to replay.

---

## 12. Administrator experience

Administrator support should be phased, but the target experience should be clear.

### 12.1 Workspace entitlement view

On a workspace or user admin page, admins should see:

```text
Plan: Business
Version: business_2026_06_v1
Display access: Business
Source: Stripe subscription
Status: Active
Limits: 100 recordings/month, ...
Current usage: 18/100 recordings this billing period
Stripe customer: cus_...
Stripe subscription: sub_...
Billing period: 2026-06-01 to 2026-07-01
```

For Private Access:

```text
Plan: Manual
Display access: Private Access
Source: Manual
Status: Active
Limits: Unlimited or custom snapshot
Reason: Founder account / family account / beta grant / support extension
```

### 12.2 Workspace admin actions

Admin actions should include:

- Grant Private Access.
- Assign a workspace to a specific plan version.
- Override workspace limits with an explicit reason.
- Expire or revoke manual access.
- View Stripe customer/subscription IDs.
- View current and historical usage.
- View audit history for entitlement changes.

### 12.3 Plan-version admin

Target plan administration:

```text
Admin -> Billing -> Plans
```

Capabilities:

- View all plans and plan versions.
- Duplicate an existing version into a draft.
- Edit draft limits.
- Attach a Stripe Price ID to a commercial draft.
- Activate a draft for new subscribers.
- Retire a version from new purchases.
- View how many workspaces remain on each version.

Active and retired versions should not allow direct limit edits.

### 12.4 Audit requirements

Every entitlement-changing admin action should create an audit event containing:

- actor/admin user
- affected workspace
- action name
- old value
- new value
- reason/note
- timestamp

This is required for manual access, overrides, plan-version assignments, status changes, and migrations.

---

## 13. Migration strategy

### 13.1 Existing workspaces

All existing workspaces should be migrated to:

```text
plan_code: manual
display: Private Access
source: manual
status: active
```

This avoids accidentally converting current known users to a limited trial or unpaid paid-plan state.

### 13.2 New workspaces

After the billing foundation is active, new workspaces default to:

```text
plan_code: trial
source: trial
status: trialing
trial_started_at: workspace creation time
trial_ends_at: trial_started_at + 14 days
```

### 13.3 Current hard-coded limits

`PlanLimits` may remain as a home for app-wide non-plan defaults such as maximum recording duration. Count-based limits should live in plan-version capability definitions and be enforced through the entitlement policy.

The desired end state is that controllers and views ask the entitlement policy for limits and availability instead of reading hard-coded constants directly.

---

## 14. Suggested implementation phases

### Phase 1 — Foundation without user-facing pricing walls

- Add plan/version/entitlement data model.
- Add a plan catalog seed or migration path.
- Migrate existing workspaces to Manual / Private Access.
- Add central entitlement policy.
- Represent limits as structured capability definitions with explicit type, period, and unit.
- Preserve existing behavior through the policy.
- Add admin read-only entitlement display and Manual grant/edit support.

### Phase 2 — Usage ledger

- Add append-only usage events.
- Record usage at reach-forward action boundaries.
- Add usage queries for lifetime trial usage and paid billing-period usage.
- Add tests proving deletion does not reduce usage.

### Phase 3 — Trial gates

- Default new workspaces to Trial.
- Add trial expiry fields and recurring expiry job.
- Add reach-forward gates for recordings, formats, exports, original audio downloads, and integrity checks.
- Add wall UI driven by structured entitlement denial reasons.

### Phase 4 — Stripe subscriptions

- Convert checkout from one-time payment to subscription mode.
- Map Starter and Business plan versions to Stripe Price IDs.
- Persist Stripe customer/subscription state.
- Add idempotent webhook processing.
- Apply subscription status, billing period, and plan version changes from Stripe events.

### Phase 5 — Plan-version administration

- Add admin plan-version list/detail pages.
- Support draft duplication, activation, retirement, and Stripe Price attachment.
- Enforce immutability for active/retired plan versions in code and tests.

---

## 15. Invariants to enforce with tests

These are product/business guarantees whose violation would be silent or costly:

- Existing workspaces are migrated to Manual / Private Access.
- New workspaces default to Trial after the billing foundation is active.
- Deleting recordings, formats, documents, exports, or downloads does not reduce usage.
- Paid usage is counted within the active monthly billing period.
- Trial usage is lifetime / total-ever.
- Existing subscribers keep old plan-version limits when a new version changes the commercial package.
- Adding a new capability key does not require changing existing entitlement snapshots.
- Quantity limits, such as recorded seconds per week, are summed from usage-event quantities rather than inferred from mutable content rows.
- Per-action limits, such as maximum recording duration, are enforced against the candidate action before acceptance.
- Manual / Private Access workspaces are not downgraded because Stripe state is missing.
- Active and retired plan-version limits cannot be edited in place.
- Stripe webhook event handling is idempotent.
- Downgrades and cancellations do not remove access before the paid-through period ends.
- Past-due subscriptions enter a 14-day grace period before lockout.

---

## 16. Open questions

- Exact Starter limits.
- Exact Business limits.
- Whether Manual / Private Access should be unlimited by default or assigned a named manual plan version with explicit high limits.
- Whether limit definitions should live entirely in the database, in seeded YAML/JSON, or in a hybrid seed-controlled catalog.
- Whether Business includes organization/team features beyond higher monthly usage.
- Whether custom per-workspace overrides should be available in phase 1 or delayed until plan-version administration exists.
- Customer-facing copy for trial walls and paid-plan comparison.
