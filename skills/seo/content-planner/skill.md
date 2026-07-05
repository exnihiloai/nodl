# Content Planner

Content strategist skill for nodl SEO. Your job is **not** to brainstorm topic ideas — that's `keyword-research`. Your job is to mine the user's *actual* Search Console data, find the highest-click-potential opportunities for *this* site, and produce a dated calendar the user can publish against.

The output is a structured `content-calendar.json` plus a Markdown summary.

**Boundary with sibling skills:**
- `keyword-research` — start from a seed, discover the keyword universe
- `content-planner` (this skill) — start from GSC, prioritize *your* opportunities, schedule them
- `content-writer` — take one planned topic and write the full post

---

## Step 1 — Setup (config + GSC)

Read and follow `../shared/preamble.md` for script paths and `GSC_API_KEY` setup.

The planner needs GSC data — if `list_gsc_sites.py` returns no properties, stop and walk the user through [gsc_setup.md](../seo-analysis/references/gsc_setup.md). Don't invent data.

Calendar and GSC cache live under `~/.nodl/seo/` (or `$NODL_SEO_DATA_DIR`):

- `{data_dir}/content-calendar.json`
- `{data_dir}/gsc-cache.json`

---

## Step 2 — Pull GSC opportunity data

Pull a wide net once, filter in memory. Fewer round-trips, better correlation.

For the chosen GSC property, fetch **last 90 days** of:

1. **Query × Page** report — top 5000 rows. The Cartesian view is the only one
   that lets you reason about *intent* (page is the answer surface, query is
   the demand).
2. **Page-only** report — top 1000 rows. Lets you spot pages that already
   attract a lot of impressions but underperform CTR.
3. **Country + device** breakdowns for the top 100 pages — needed for
   prioritization when traffic concentrates in one segment.

Cache the raw pull at `{data_dir}/gsc-cache.json` with a `fetchedAt` timestamp.
Re-use the cache for 7 days — opportunities don't shift hourly.

---

## Step 3 — Classify opportunities

For every (query, page) row, classify into one of these buckets. Discard rows
that don't fit any bucket — noise.

### A. Striking-distance queries (highest priority)
- Position **5-20**, impressions **≥ 100/90d**, query is informational
- The page already ranks; a content refresh or net-new post targeting the
  exact intent can move it into the top 5

### B. Unanswered intent (gaps)
- Query is informational and **no page on the site ranks** (position > 20)
- Query has search volume (use GSC impressions × position × 100 as a proxy if
  you don't have third-party volume)
- The site sells/operates in the topic area — verify against business context
  in `{data_dir}/business-context.json` if present

### C. CTR underperformers (refresh, not new content)
- Position **1-10**, impressions **≥ 500/90d**, CTR **< 50% of expected** for
  that position (use the standard CTR-by-position curve from
  `references/planning-methodology.md`)
- Output a *refresh* task, not a new post. Route to `meta-tags-optimizer` for
  the title/description rewrite.

### D. Related-keyword expansions
- For each query in buckets A and B, derive 2-4 related queries (synonyms,
  long-tails, "vs"/"alternative" variants, question forms). Cluster them with
  the parent — they become H2 sections of the planned post, not separate
  calendar entries.

### E. Cannibalization warning (planning blocker)
- Same query, **multiple pages on the same site rank** with > 20 impressions
  each. Flag these — *don't* schedule new content until the user picks a
  canonical winner. Route to `seo-analysis` for cannibalization fix.

See `references/planning-methodology.md` for the full classification rubric
and the click-potential formula.

---

## Step 4 — Score click potential

For every candidate topic that survives Step 3, compute:

```
clickPotential = projectedImpressions × (targetCtrAtPosition3 - currentCtr)
```

Where:
- `projectedImpressions` = 90d impressions × seasonality factor (default 1.0)
- `targetCtrAtPosition3` = 0.10 (from the standard CTR curve; informational
  posts cluster lower than transactional)
- `currentCtr` = actual GSC CTR for this query, or 0 if the site doesn't rank

Sort by `clickPotential` descending. Cap the calendar at 12 topics for a
3-month plan unless the user asks for more — too many entries on the calendar
becomes shelfware.

---

## Step 5 — Build the calendar

Schedule one post per week, P0s first. Format every entry against this schema:

```json
{
  "id": "<slug>",
  "title": "<hook-driven title, ≤ 60 chars>",
  "primaryKeyword": "<from GSC>",
  "secondaryKeywords": ["<related cluster from Step 3D>"],
  "intent": "informational|commercial",
  "type": "blog|landing|refresh",
  "opportunity": "striking-distance|gap|ctr-underperformer|related-expansion",
  "scheduledDate": "<YYYY-MM-DD>",
  "status": "planned",
  "priority": "P0|P1|P2",
  "gsc": {
    "currentPosition": <number>,
    "impressions90d": <number>,
    "currentCtr": <number 0-1>,
    "clickPotential": <number>
  },
  "rationale": "<one sentence: why this topic, why now>",
  "writerPrompt": "<the exact prompt to paste into /content-writer when it's time to write>",
  "refreshTarget": "<URL of existing page, only set when type=refresh>",
  "bodyPath": "<relative path to written markdown body, set after /content-writer runs>",
  "metaDescription": "<set after /content-writer runs>",
  "featuredImage": { "url": "...", "alt": "..." },
  "inlineImages": [{ "url": "...", "alt": "...", "placement": "..." }],
  "structuredData": { "@context": "https://schema.org", "@type": "BlogPosting" }
}
```

### Status lifecycle

| Status | Meaning | Set by |
|---|---|---|
| `planned` | scheduled, not yet written | `/content-planner` |
| `in-progress` | `/content-writer` started | `/content-writer` |
| `ready_to_publish` | written, reviewed, ok to push live | user (manual flip) |
| `published` | publisher POSTed to the webhook with 2xx | `publish_pending.py` |
| `failed` | publisher got 4xx; needs user fix | `publish_pending.py` |

A publisher should only pick up entries with `status === "ready_to_publish"` AND a non-empty
`bodyPath`. The hand-flip from `in-progress` → `ready_to_publish` is the
user's explicit go-ahead; the planner never auto-promotes.

Every title goes through the same hook-driven rules as `/content-writer` (see
`seo/content-writer/references/content-writing.md` → "Title Hook Patterns").
Don't ship a calendar with bare-keyword titles.

Write the full calendar to `{data_dir}/content-calendar.json`:

```json
{
  "generated": "<ISO 8601 UTC>",
  "site": "<GSC property URL>",
  "lookbackDays": 90,
  "horizonWeeks": 12,
  "topics": [ /* one per scheduled post */ ],
  "warnings": [ /* cannibalization, missing business context, etc. */ ]
}
```

Merge with an existing calendar instead of overwriting:
- Topics already marked `in-progress` or `published` are **preserved as-is**
- New planned topics are appended; duplicates by `primaryKeyword` are dropped
  in favor of the existing entry

---

## Step 6 — Present

Print:

1. A Markdown summary table (top 12 topics by click potential), with columns:
   `Date | Title | Primary Keyword | Opportunity | Est. Clicks Gained | P`
2. The path to the JSON: `{data_dir}/content-calendar.json`

3. Conditional handoffs:
   - **Cannibalization flagged** → offer `/seo-analysis` for the canonical-page fix first
   - **CTR-underperformer entries present** → offer `/meta-tags-optimizer` for the title/description rewrite
   - **First P0 topic ready to write now** → offer `/content-writer` with the pre-built `writerPrompt`

---

## Step 7 — Quality gate

Refuse to ship the calendar if any of these are true:

- [ ] GSC didn't connect → stop, walk through gsc_setup.md
- [ ] < 50 (query, page) rows pulled → site has too little data, plan would be
      speculation; tell the user so and stop
- [ ] Any topic has a bare-keyword title → rewrite with a hook before writing
      the JSON
- [ ] Two scheduled topics share the same `primaryKeyword` → cannibalization
      by your own plan; collapse or de-prioritize one
- [ ] Cannibalization warning present and ignored in the calendar → block,
      surface the warning, ask the user to confirm

This skill writes one artifact and one summary. Don't add tangential analysis
the user didn't ask for.
