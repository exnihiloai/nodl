# SEO: Localized Marketing URLs and Operator Content Pages

Shipped in v0.27.0 (2026-07-05). Documents the URL-locale contract, the operator
article system, and the crawler-facing surfaces (canonical/hreflang, sitemap,
llms.txt, structured data).

## Problem

The app resolved the locale per request (session → user preference →
`Accept-Language` → default `:en`). For crawlers — which send no German
`Accept-Language` — every public URL rendered **English**, including the
German-slugged vertical pages (`/fuer/tagebuch` etc.). German content was
effectively unindexable, no URL had a stable language, and hreflang was
impossible because no language-specific URLs existed. Additionally the homepage
emitted every JSON-LD block twice (layout fallback + private template).

## URL-locale contract

The route fixes the locale via route `defaults`; only route defaults count
(query strings do not switch languages):

| URL space | Locale | Route names |
|---|---|---|
| `/fuer/aerzte`, `/fuer/zahnaerzte`, `/fuer/gedankenkarussell`, `/fuer/tagebuch`, `/fuer/interviews`, `/fuer/coaches` | always `de` | `for_doctors_path`, … |
| `/for/doctors`, `/for/dentists`, `/for/racing-mind`, `/for/journaling`, `/for/interviews`, `/for/coaches` | always `en` | `for_doctors_en_path`, … |
| `/artikel/:slug` | always `de` | `artikel_path(slug)` |
| `/articles/:slug` | always `en` | `article_path(slug)` |
| Everything else (home, about, app) | session/header-based as before | |

Implementation: `ApplicationController#current_locale` prefers
`request.path_parameters[:locale]` (set only by route defaults) over session,
user preference, and header. DE and EN vertical URLs share one controller
action and one private template; the template renders in the fixed locale.

## Canonical + hreflang

`SeoHelper#seo_link_tags` (rendered in the layout `<head>`) emits:

- Vertical pages: self-canonical + `hreflang` `de`/`en`/`x-default`
  (x-default → EN variant). Pair map: `SeoHelper::LOCALIZED_PAGE_PAIRS`.
- Home, about, try-now: plain self-canonical (single-URL pages).
- Content pages: self-canonical (articles are single-language; no hreflang).

All canonical URLs use `StructuredDataHelper::CANONICAL_BASE`
(`https://nodl.now`), independent of the request host.

## Operator content pages (articles)

`ContentPagesController#show` renders templates from the private companion
repo: `private/views/content/<locale>/<slug>.html.erb`. Contract:

- Slug format `\A[a-z0-9]+(?:-[a-z0-9]+)*\z` (`PrivateContent::CONTENT_SLUG_FORMAT`),
  validated twice (route constraint + `PrivateContent.content_page?`), `format: false`.
- Missing template or no `private/` → 404, mirroring the marketing-page contract.
- `Sitemap.content_entries` enumerates `PrivateContent.content_slugs(locale)`
  for both locales — new articles appear in `/sitemap.xml` automatically.

**Adding an article** (private repo only, no code change): create
`private/views/content/de/<slug>.html.erb` (or `en/`). The template supplies
its own `content_for :title`, meta description, and JSON-LD
(`json_ld_tag`, `breadcrumb_schema`, `faq_page_schema` helpers are available).
Existing articles under `private/views/content/` show the pattern
(prose layout, FAQ section, internal links, CTA).

## Structured data

- The layout renders `shared/homepage_structured_data` only when
  `PrivateContent.marketing?` is false (OSS shell). Private home templates ship
  their own richer JSON-LD — previously both rendered, duplicating every block.
- Vertical pages: `BreadcrumbList` + `FAQPage`; home: `Organization`,
  `WebSite`, `SoftwareApplication`, `FAQPage`; articles: `Article`,
  `BreadcrumbList`, `FAQPage`.

## Crawler surfaces

- `config/llms.txt` / `config/llms-full.txt` list both language variants of the
  vertical pages and all articles — extend them when adding articles.
- `robots.txt` explicitly allows AI crawlers; Cloudflare AI Crawl Control has
  no blocks (verified 2026-07-05: ClaudeBot/PerplexityBot crawling with 200s).
- Bing Webmaster Tools is set up for `nodl.now` (GSC import, sitemap
  submitted 2026-07-05) — relevant because ChatGPT search uses the Bing index.
- GSC sitemap can be re-submitted programmatically:
  `PUT https://www.googleapis.com/webmasters/v3/sites/sc-domain%3Anodl.now/sitemaps/<encoded-url>`
  with a token from `.claude/skills/seo-analysis/scripts/_gsc_auth.py`.

## Tests

- `test/integration/localized_marketing_pages_test.rb` — URL fixes locale
  (against session and header), hreflang/canonical tags, EN twins in sitemap,
  404 without private views.
- `test/integration/content_pages_test.rb` — article rendering per locale,
  slug validation, 404 contracts, sitemap inclusion/exclusion.
- `test/integration/structured_data_test.rb` — schema presence + no duplicate
  JSON-LD types on the homepage.

## Known limitations / follow-ups

- The homepage serves both languages on one URL (session-based); Google indexes
  the EN version. A German homepage URL (e.g. `/de`) would be an architecture
  decision, deliberately deferred.
- `AppVersion` reads the first `## [x.y.z]` heading in `CHANGELOG.md` — an
  `## [Unreleased]` section breaks `test/lib/app_version_test.rb`; version
  changelog entries directly.
- Operator baseline data and the SEO strategy live in the private repo
  (`private/seo/`), not here.
